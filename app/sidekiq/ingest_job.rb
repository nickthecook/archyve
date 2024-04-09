class IngestJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    @document = Document.find(args.first)

    TheIngestor.new(@document).ingest
  end
end
