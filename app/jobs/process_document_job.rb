# Runs a Document through the ingestion pipeline: extract (Docling) -> chunk ->
# embed (nomic via Ollama) -> store. Drives document.status so the UI can show
# progress later. Idempotent: reprocessing clears prior chunks/embeddings first,
# so a re-run after a failure or a re-embed is safe.
class ProcessDocumentJob < ApplicationJob
  queue_as :ingestion

  # Serialize per document so two runs (a reprocess enqueued while the first is
  # still embedding, or a reclaimed job after a worker dies) can't race on
  # destroy_all + positional inserts. Others block and run after, redoing the
  # work to a consistent end. (Engages under the solid_queue adapter — prod;
  # dev runs jobs one at a time.) The unique (document_id, position) index is the
  # hard backstop if a race ever slips through.
  limits_concurrency key: ->(document) { document.id }, to: 1, duration: 15.minutes

  class MissingFile < StandardError; end

  def perform(document)
    document.update!(status: :processing)

    result = extract(document)
    chunks = Ingestion::Chunker.new.chunk(result)
    store(document, chunks)

    document.update!(status: :processed)
  rescue StandardError => e
    document.update!(status: :failed) if document.persisted?
    Rails.logger.error("ProcessDocumentJob failed for document #{document.id}: #{e.class}: #{e.message}")
    raise
  end

  private

  def extract(document)
    raise MissingFile, "document #{document.id} has no attached file" unless document.file.attached?

    document.file.blob.open do |file|
      Docling::Client.new.convert(
        file,
        filename: document.file.filename.to_s,
        content_type: document.file.content_type || "application/octet-stream"
      )
    end
  end

  # No single wrapping transaction: embedding each chunk is a slow Ollama call,
  # and we don't want to hold a transaction open across all of them. Instead we
  # rely on idempotency — clear prior chunks up front, and only mark the document
  # `processed` once every chunk is stored, so a mid-run failure is recovered by
  # simply re-running the job.
  def store(document, chunks)
    document.chunks.destroy_all
    chunks.each_with_index do |chunk, position|
      record = document.chunks.create!(position: position, content: chunk.content, structure: chunk.structure)
      embed(record)
    end
  end

  def embed(chunk)
    chunk.embeddings.create!(
      embedding: Embeddings::Embed.document(chunk.content),
      embedding_model: Embedding::DEFAULT_MODEL
    )
  end
end
