class ConvertDocumentJob
  include Sidekiq::Job

  sidekiq_options retry: 1
  sidekiq_retries_exhausted do |job, exception|
    document = Document.find(job['args'].first)

    document.update!(state: :errored, error_message: exception.to_s)
  end

  attr_reader :new_doc

  def perform(document_id)
    document = Document.find(document_id)
    converter = Converters.find(document)
    @new_doc = converter.convert
    @new_doc.save!
    # Pass it back to Mediator for next step
    Mediator.ingest(@new_doc) unless @new_doc.errored?
  end
end
