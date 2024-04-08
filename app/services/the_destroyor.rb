class TheDestroyor
  DELETE_BATCH_SIZE = 10

  def initialize(document)
    @document = document
  end

  def destroy
    @document.deleting!

    @document.chunks.select(:id, :vector_id).find_in_batches(batch_size: DELETE_BATCH_SIZE) do |chunks|
      Rails.logger.info("Destroying batch of #{chunks.count} chunks...")
      chromadb.delete_documents(collection_id, chunks.map(&:vector_id))

      Chunk.delete(chunks)
    end

    @document.destroy!
  end

  private

  def collection_id
    @collection_id ||= chromadb.collection_id(@document.collection.slug)
  end

  def chromadb
    @chromadb ||= Chromadb::Client.new
  end
end
