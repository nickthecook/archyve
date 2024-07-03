require "httparty"

module Chromadb
  class Client
    attr_reader :last_response

    def initialize(host = nil, port = nil)
      @host = host || ENV.fetch("CHROMADB_HOST") { "localhost" }
      @port = port || ENV.fetch("CHROMADB_PORT") { 8000 }
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
      Rails.logger.info("[CHROMADB] GET #{path}")
      @last_response = HTTParty.get(url(path), headers: { "Content-Type" => "application/json" })

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      store_api_call("chromadb", @last_response)

      @last_response.parsed_response
    end

    def post(path, body = {})
      Rails.logger.info("[CHROMADB] POST #{path}")
      @last_response = HTTParty.post(url(path), headers: { "Content-Type" => "application/json" }, body: body.to_json)

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      store_api_call("chromadb", @last_response)

      @last_response.parsed_response
    end

    def delete(path)
      Rails.logger.info("[CHROMADB] DELETE #{path}")
      @last_response = HTTParty.delete(url(path), headers: { "Content-Type" => "application/json" })

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      store_api_call("chromadb", @last_response)

      @last_response.parsed_response
    end

    def store_api_call(service_name, response)
      ApiCall.from_httparty(service_name, response).save!
    end
  end
end
