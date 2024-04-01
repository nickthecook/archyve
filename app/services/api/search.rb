module Api
  class Search
    class SearchError < StandardError; end

    include Rails.application.routes.url_helpers

    def initialize(collection)
      @collection = collection
    end

    def search(query)
      raise SearchError, "No query given" if query.blank?

      embedded_query = embedder.embed(query)
      results = chroma.query(collection_id, [embedded_query], return_objects: true)

      Rails.logger.info("ChromaDB results:\n#{results}")

      apply_filters(results, :add_chunk_ids, :add_document_urls, :remove_documents)
    end

    private

    def apply_filters(results, *filter_names)
      filter_names.each do |filter|
        send(filter, results)
      end

      results
    end

    def add_chunk_ids(results)
      results.map! do |result|
        vector_id = result[:id]
        chunk_id = Chunk.select("id").find_by(vector_id:).id

        result[:vector_id] = vector_id
        result[:id] = chunk_id

        result
      end
    end

    def add_document_urls(results)
      results.map! do |result|
        chunk = Chunk.find(result[:id])
        # TODO: make this dynamic, based on url_helpers
        result[:url] = "/v1/chunks/#{chunk.id}"

        result
      end
    end

    def remove_documents(results)
      results.map! do |result|
        result.delete(:document)

        result
      end
    end

    def broadcast_chunk(chunk, distance)
      Turbo::StreamsChannel.broadcast_append_to(
        :collection, target: @dom_id, partial: @partial, locals: { chunk:, distance: }
      )
    end

    def chunk_for(id)
      chunk = Chunk.find_by(vector_id: id)

      if chunk.present?
        Rails.logger.info("Got hit for chunk #{id} in collection #{@collection.slug}.")
      else
        Rails.logger.warn("Could not find chunk with id #{id} while searching collection #{@collection.slug}.")
      end

      chunk
    end

    def collection_id
      chroma.collection_id(@collection.slug)
    end

    def embedder
      @embedder ||= Embedder.new
    end

    def chroma
      @chroma ||= Chromadb::Client.new
    end
  end
end
