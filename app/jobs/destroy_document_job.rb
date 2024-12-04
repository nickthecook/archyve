class DestroyDocumentJob
  include Sidekiq::Job

  def perform(*args)
    document = Document.find(args.first)

    DestroyDocument.new(document).execute
  end
end
