require "httparty"
module Chromadb
  class RequestError < StandardError; end
  class ResponseError < StandardError; end

  class Client
    attr_reader :last_response

    def initialize(host, port)
      @host = host
      @port = port
      @url = "http://#{@host}:#{@port}"
    end

    def version
      get("api/v1/version")
    end
  
    def create_collection(name, metadata = nil, tenant = nil, database = nil)
      body = { name: }
      body[:metadata] = metadata if metadata

      post("api/v1/collections", body)
    end

    def collection_id(collection_name)
      get_collection(collection_name)["id"]
    rescue ResponseError
      nil
    end

    def collections(name = nil)
      if name
        get_collection(name)
      else
        get_collections
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

    def query(collection_id, embeddings)
      post("api/v1/collections/#{collection_id}/query", { query_embeddings: embeddings })
    end

    def delete_collection(collection_name)
      delete("api/v1/collections/#{collection_name}")
    end

    def empty_collection(collection_name)
      collection = get_collection(collection_name)

      delete_collection(collection_name)

      response = create_collection(collection["name"], collection["metadata"], collection["tenant"], collection["database"])

      response["id"]
    end

    private

    def get_collection(name)
      get("api/v1/collections/#{name}")
    end

    def get_collections
      get("api/v1/collections")
    end

    def get(path)
      @last_response = HTTParty.get(url(path), headers: { "Content-Type" => "application/json" })

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      @last_response.parsed_response
    end

    def post(path, body = {})
      @last_response = HTTParty.post(url(path), headers: { "Content-Type" => "application/json" }, body: body.to_json)

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      @last_response.parsed_response
    end

    def delete(path)
      @last_response = HTTParty.delete(url(path), headers: { "Content-Type" => "application/json" })

      unless @last_response.success?
        raise ResponseError, @last_response.body
      end

      @last_response.parsed_response
    end

    def url(path)
      "#{@url}/#{path}"
    end
  end
end
