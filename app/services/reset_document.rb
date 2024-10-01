class ResetDocument
  def initialize(document)
    @document = document
  end

  def execute
    Rails.logger.warn("RESETTING DOCUMENT #{@document.id}: is in state #{@document.state}...")

    destroyor = TheDestroyor.new(@document)
    destroyor.delete_embeddings
    destroyor.delete_chunks
    destroyor.delete_graph_entities

    @document.update!(state: :created, error_message: nil)
  end
end
