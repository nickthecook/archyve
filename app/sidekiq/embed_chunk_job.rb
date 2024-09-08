class EmbedChunkJob
  include Sidekiq::Job

  sidekiq_options retry: Rails.configuration.sidekiq_retries, queue: "llm"

  sidekiq_retries_exhausted do |job, _exception|
    chunk = Chunk.find(job['args'].first)

    chunk.document.update!(state: :errored)
  end

  def perform(chunk_id)
    chunk = Chunk.find(chunk_id)

    EmbedChunk.new(chunk).execute

    return unless chunk.collection.graph_enabled?

    ExtractChunkEntitiesJob.perform_async(chunk_id)
  end
end
