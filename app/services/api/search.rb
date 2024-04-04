module Api
  class Search
    class SearchError < StandardError; end

    include Rails.application.routes.url_helpers

    def initialize(collection, base_url: nil)
      @collection = collection
      @base_url = base_url
    end

    def search(query)
      raise SearchError, "No query given" if query.blank?

      embedded_query = embedder.embed(query)
      results = chroma.query(collection_id, [embedded_query], return_objects: true)

      Rails.logger.info("ChromaDB results:\n#{results}")

      apply_filters(
        results,
        :add_chunks,
        :remove_null_chunks,
        :add_chunk_ids,
        :add_document_urls,
        :remove_chunks
      )
    end

    private

    def add_chunks(results)
      results.each do |result|
        result[:chunk] = chunk_for(result[:id])
      end
    end

    def remove_null_chunks(results)
      results.reject! { |result| result[:chunk].nil? }
    end

    def apply_filters(results, *filter_names)
      filter_names.each do |filter|
        send(filter, results)
      end

      results
    end

    def add_chunk_ids(results)
      results.map! do |result|
        vector_id = result[:id]

        result[:vector_id] = vector_id
        result[:id] = result[:chunk]&.id

        result
      end
    end

    def add_document_urls(results)
      results.map! do |result|
        chunk = result[:chunk]
        # TODO: make this dynamic, based on url_helpers
        # TODO: probably make this a link for a browser, once chunks#show is implemented
        result[:url] = "#{@base_url}/v1/chunks/#{chunk.id}"
        result[:browser_url] = url_for(chunk)

        result
      end
    end

    def remove_chunks(results)
      results.each do |result|
        result.delete(:chunk)
      end
    end

    def url_for(chunk)
      collection_document_chunk_url(
        chunk.collection,
        chunk.document,
        chunk,
        host: @base_url
      )
    end

    def chunk_for(vector_id)
      chunk = Chunk.find_by(vector_id:)

      if chunk.nil?
        Rails.logger.warn("Could not find chunk with id #{vector_id} while searching collection #{@collection.slug}.")
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
