class ContextualizeChunkJob
  include Sidekiq::Job

  sidekiq_retries_exhausted do |job, exception|
    chunk = Chunk.find(job["args"].first)

    chunk.document.update!(state: :error, error_message: exception.to_s)
  end

  def perform(chunk_id)
    chunk = Chunk.find(chunk_id)

    ContextualRetrieval::ChunkContextualizer.new(chunk).execute

    EmbedChunkJob.perform_async(chunk.id)
  end
end
