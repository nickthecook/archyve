class ExtractChunkEntitiesJob
  include Sidekiq::Job

  sidekiq_options retry: Rails.configuration.sidekiq_retries, queue: "llm"

  sidekiq_retries_exhausted do |job, exception|
    chunk = Chunk.find(job['args'].first)

    chunk.document.update!(state: :errored, error_message: exception.to_s)
  end

  def perform(chunk_id)
    chunk = Chunk.find(chunk_id)

    Graph::ExtractChunkEntities.new(chunk).execute
  end
end
