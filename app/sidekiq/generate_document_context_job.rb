class GenerateDocumentContextJob
  include Sidekiq::Job

  sidekiq_retries_exhausted do |job, exception|
    Rails.logger.error "Error in #{job["class"]} with args #{job["args"]}: #{exception}"
    document = Document.find(job["args"].first)

    document.update!(state: :error, error_message: e.to_s)
  end

  def perform(*args)
    document = Document.find(args.first)

    ContextualRetrieval::DocumentContextGenerator.new(document).execute

    ChunkDocumentJob.perform_async(document.id)
  end
end
