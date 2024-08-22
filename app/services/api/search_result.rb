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

    def id
      @search_hit.reference.id
    end

    def document
      @search_hit.content
    end

    def distance
      @search_hit.distance
    end

    def vector_id
      @search_hit.reference.vector_id
    end

    def url
      return chunk_url if chunk.present?

      entity_url if entity.present?
    end

    def browser_url
      return chunk_browser_url if chunk.present?

      entity_browser_url
    end

    def relevant
      @search_hit.relevant
    end

    private

    def chunk_url
      "#{@base_url}/v1/collections/#{chunk.collection.id}/documents/#{chunk.document.id}/chunks/#{chunk.id}"
    end

    def entity_url
      "#{@base_url}/v1/collections/#{entity.collection.id}/entities/#{entity.id}"
    end

    def chunk_browser_url
      collection_document_chunk_url(
        chunk.collection,
        chunk.document,
        chunk,
        host: @browser_base_url.host,
        protocol: @browser_base_url.scheme,
        port: @browser_base_url.port
      )
    end

    def entity_browser_url
      collection_entity_url(
        entity.collection,
        entity,
        host: @browser_base_url.host,
        protocol: @browser_base_url.scheme,
        port: @browser_base_url.port
      )
    end

    def chunk
      @chunk ||= @search_hit.reference if @search_hit.reference.is_a?(Chunk)
    end

    def entity
      @entity ||= @search_hit.reference if @search_hit.reference.is_a?(GraphEntity)
    end
  end
end
