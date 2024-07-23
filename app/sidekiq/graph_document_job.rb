class GraphDocumentJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    @document = Document.find(args.first)

    Graph::GraphDocument.new(@document).graph
  end
end
