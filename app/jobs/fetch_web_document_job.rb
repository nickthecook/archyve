class FetchWebDocumentJob
  include Sidekiq::Job

  def initialize(document)
    @document = document
  end

  def perform(document_id)
    document = Document.find(document_id)

    FetchWebDocument.new(document).execute
  end
end
