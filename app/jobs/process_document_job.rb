# Runs a Document through the ingestion pipeline: extract (Docling) -> chunk ->
# embed (nomic via Ollama) -> store. Drives document.status so the UI can show
# progress later. Idempotent: reprocessing clears prior chunks/embeddings first,
# so a re-run after a failure or a re-embed is safe.
#
# Every verdict is also recorded *on the document* — see Ingestion::Outcome —
# rather than only logged. A log line is only useful to someone who already
# knows which document to go looking for, which is exactly what the person
# staring at a red badge does not know.
class ProcessDocumentJob < ApplicationJob
  queue_as :ingestion

  # Serialize per document so two runs (a reprocess enqueued while the first is
  # still embedding, or a reclaimed job after a worker dies) can't race on
  # destroy_all + positional inserts. Others block and run after, redoing the
  # work to a consistent end. (Engages under the solid_queue adapter — prod;
  # dev runs jobs one at a time.) The unique (document_id, position) index is the
  # hard backstop if a race ever slips through.
  limits_concurrency key: ->(document) { document.id }, to: 1, duration: 15.minutes

  # Raised nowhere but here: tags whatever a stage threw with the name of that
  # stage, so the rescue below can say *where* the pipeline gave up without
  # every service having to know it is part of a pipeline.
  class StageError < StandardError
    attr_reader :stage, :original

    def initialize(stage, original)
      @stage = stage
      @original = original
      super("#{stage}: #{original.class}: #{original.message}")
    end
  end

  def perform(document)
    document.begin_processing!

    result = stage(:extract) { extract(document) }
    chunks = stage(:chunk) { chunk(result) }
    stage(:store) { store(document, chunks) }

    finish(document, result)
  rescue StageError => e
    record_failure(document, Ingestion::Outcome.classify(e.original, stage: e.stage))
    # Re-raise what actually went wrong, not our wrapper: the queue's retries
    # and anything watching the job should see the real exception and its
    # backtrace, not a label we invented for the UI.
    raise e.original
  rescue StandardError => e
    # Outside any stage — a database write, most likely. No stage to name.
    record_failure(document, Ingestion::Outcome.classify(e))
    raise
  end

  private

  # Run a stage, tagging anything it raises with the stage's name. Nested
  # stages keep the innermost name: embedding happens inside `store`, and
  # "embed" is the answer worth having there.
  def stage(name)
    yield
  rescue StageError
    raise
  rescue StandardError => e
    raise StageError.new(name, e)
  end

  # The document is stored and searchable either way; the only question is
  # whether all of it made it. A shortfall is kept on the row rather than
  # logged and forgotten, because "this manual is missing page 2" is something
  # a reader deserves to know months later, not only while the job is running.
  def finish(document, result)
    if result.partial?
      document.record_shortfall!(Ingestion::Outcome.partial_extraction(result))
    else
      document.update!(status: :processed)
    end
  end

  def record_failure(document, outcome)
    Rails.logger.error(
      "ProcessDocumentJob failed for document #{document.id} " \
      "[stage=#{outcome.stage || 'none'} kind=#{outcome.kind}]: #{outcome.detail}"
    )
    document.record_failure!(outcome) if document.persisted?
  end

  # A document that chunks to nothing is not a processed document. Caught here
  # rather than left to produce a cheerful empty page, because the two ways to
  # arrive at it — an empty file, and a partial conversion whose surviving
  # pages held no text — both end with an archive entry nothing can ever
  # retrieve.
  def chunk(result)
    chunks = Ingestion::Chunker.new.chunk(result)
    raise Ingestion::NothingReadable, "extraction produced no text to chunk" if chunks.empty?

    chunks
  end

  def extract(document)
    raise Ingestion::MissingFile, "document #{document.id} has no attached file" unless document.file.attached?

    document.file.blob.open do |file|
      Docling::Client.new.convert(
        file,
        filename: document.file.filename.to_s,
        content_type: document.file.content_type || "application/octet-stream",
        ocr: document.ocr?
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
      stage(:embed) { embed(record) }
    end
  end

  # embedding_model stays a free-text string on the row rather than a foreign
  # key: it is the durable record of what produced this vector, and has to
  # outlive the InferenceModel being renamed or deleted.
  def embed(chunk)
    chunk.embeddings.create!(
      embedding: Embeddings::Embed.document(chunk.content),
      embedding_model: InferenceModel.active_embedding.name
    )
  end
end
