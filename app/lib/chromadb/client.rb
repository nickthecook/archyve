require "httparty"

module Chromadb
  # rubocop:disable Metrics/ClassLength
  class Client
    attr_reader :last_response

    def initialize(host = nil, port = nil, traceable: nil)
      @host = host || ENV.fetch("CHROMADB_HOST") { "localhost" }
      @port = port || ENV.fetch("CHROMADB_PORT") { 8000 }
      @traceable = traceable

      @url = "http://#{@host}:#{@port}"
    end

    def version
      get("api/v1/version")
    end

    def create_collection(name, metadata = nil, _tenant = nil, _database = nil)
      body = { name: }
      body[:metadata] = metadata if metadata

      post("api/v1/collections", body)
    end

    def collection_id(collection_name)
      _collection(collection_name)["id"]
    rescue ResponseError
      nil
    end

    def collections(name = nil)
      if name
        _collection(name)
      else
        _collections
      end
    end

    # TODO: add_summary takes one item but add_documents takes many; odd?
    # Also, there are going to be more of these. Establish a pattern when the third is added.
    def add_entity_summary(collection_id, summary, embedding)
      id = SecureRandom.uuid

      post("api/v1/collections/#{collection_id}/add", {
        ids: [id],
        documents: [summary],
        embeddings: [embedding],
        metadatas: [{ type: "entity_summary" }],
      })

      id
    end

    def add_documents(collection_id, documents, embeddings)
      ids = documents.map { |_doc| SecureRandom.uuid }

      post("api/v1/collections/#{collection_id}/add", { ids:, documents:, embeddings: })

      ids
    end

    def count(collection_id)
      get("api/v1/collections/#{collection_id}/count")
    end

    def get_documents(collection_id, ids = nil)
      body = {}
      body[:ids] = ids if ids

      post("api/v1/collections/#{collection_id}/get", body)
    end

    def query(collection_id, embeddings, return_objects: false)
      response = post("api/v1/collections/#{collection_id}/query", { query_embeddings: embeddings })
      return response unless return_objects

      Responses::Query.new(response).objects
    end

    def delete_collection(collection_name)
      delete("api/v1/collections/#{collection_name}")
    end

    def delete_documents(collection_id, ids)
      post("api/v1/collections/#{collection_id}/delete", { ids: })
    end

    def empty_collection(collection_name)
      collection = _collection(collection_name)

      delete_collection(collection_name)

      response = create_collection(
        collection["name"],
        collection["metadata"],
        collection["tenant"],
        collection["database"]
      )

      response["id"]
    end

    def url(path = nil)
      return @url unless path

      "#{@url}/#{path}"
    end

    private

    def _collection(name)
      get("api/v1/collections/#{name}")
    end

    def _collections
      get("api/v1/collections")
    end

    def get(path)
      @last_response = HTTParty.get(url(path), headers: { "Content-Type" => "application/json" })

      store_api_call("chromadb", @last_response)

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      @last_response.parsed_response
    end

    def post(path, body = {})
      @last_response = HTTParty.post(url(path), headers: { "Content-Type" => "application/json" }, body: body.to_json)

      store_api_call("chromadb", @last_response)

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      @last_response.parsed_response
    end

    def delete(path)
      @last_response = HTTParty.delete(url(path), headers: { "Content-Type" => "application/json" })

      store_api_call("chromadb", @last_response)

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      @last_response.parsed_response
    end

    def store_api_call(service_name, response)
      ApiCall.from_httparty(service_name, response, @traceable).save!
    end
  end
  # rubocop:enable Metrics/ClassLength
end
