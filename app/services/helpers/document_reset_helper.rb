module Helpers
  class DocumentResetHelper
    DELETE_BATCH_SIZE = 100

    def initialize(document, chromadb: nil)
      @document = document
      @chromadb = chromadb
    end

    # Reset the document by destroying all it's related content / children, leaving the document itself intact
    def execute
      @document.children.each do |doc|
        doc.deleting!
        DocumentResetHelper.new(doc, chromadb:).execute
        doc.destroy!
      end

      delete_embeddings
      delete_chunks
      delete_graph_entities
      @document.reset!
    end

    private

    def delete_embeddings
      @document.chunks.select(:id, :vector_id).find_in_batches(batch_size: DELETE_BATCH_SIZE) do |chunks|
        Rails.logger.info("Destroying batch of #{chunks.count} chunks...")
        chromadb.delete_documents(collection_id, chunks.map(&:vector_id))

        Chunk.destroy(chunks)
      rescue Chromadb::ResponseError => e
        Rails.logger.error("Failed to delete batch of #{chunks.count} chunks: #{e}\n
        Destruction of document #{@document.id} will continue, but chunks may remain in ChromaDB.")
      end
    end

    def delete_chunks
      @document.chunks.destroy_all
    end

    def delete_graph_entities
      @document.graph_entity_descriptions.destroy_all

      Graph::CleanCollectionEntities.new(@document.collection).execute
    end

    def collection_id
      @collection_id ||= chromadb.collection_id(@document.collection.slug)
    end

    def chromadb
      @chromadb ||= Chromadb::Client.new
    end
  end
end
