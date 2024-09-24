class ContextualizeChunkJob
  include Sidekiq::Job

  sidekiq_retries_exhausted do |job, exception|
    Rails.logger.error "Error in #{job['class']} with args #{job['args']}: #{exception}"
  end

  def perform(chunk_id)
    chunk = Chunk.find(chunk_id)

    ChunkContextualizer.new(chunk).execute

    EmbedChunkJob.perform_async(chunk.id)
  end
end
