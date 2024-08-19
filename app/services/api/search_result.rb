module Api
  class SearchResult
    include Rails.application.routes.url_helpers

    def initialize(search_hit, base_url, browser_base_url)
      @search_hit = search_hit
      @base_url = base_url
      @browser_base_url = URI(browser_base_url)
    end

    def to_h
      {
        id:,
        metadata: "", # TODO: provide metadata from ChromaDB
        document:,
        distance:,
        vector_id:,
        url:,
        browser_url:,
        relevant:,
      }
    end

    delegate :id, to: :chunk

    def document
      chunk.content
    end

    def distance
      @search_hit.distance
    end

    delegate :vector_id, to: :chunk

    def url
      "#{@base_url}/v1/chunks/#{chunk.id}"
    end

    def browser_url
      collection_document_chunk_url(
        chunk.collection,
        chunk.document,
        chunk,
        host: @browser_base_url.host,
        protocol: @browser_base_url.scheme,
        port: @browser_base_url.port
      )
    end

    def relevant
      @search_hit.relevant
    end

    private

    def chunk
      @chunk ||= @search_hit.reference
    end
  end
end
