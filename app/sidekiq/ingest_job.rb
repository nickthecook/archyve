class IngestJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    @document = Document.find(args.first)
    @chunking_profile = ChunkingProfile.find(args.second)

    TheIngestor.new(@document, @chunking_profile).ingest
  end
end
