require "httparty"
module Chromadb
  class RequestError < StandardError; end

  class Client
    def initialize(host, port)
      @host = host
      @port = port
      @url = "http://#{@host}:#{@port}"
    end

    def collections(name = nil)
      if name
        get_collection(name)
      else
        get_collections
      end
    end

    def get_documents(collection_name, ids)
      post("api/v1/collections/#{collection_name}/get", body: {ids: ids})
    end

    def query(collection_name, embeddings)
      post("api/v1/collections/#{collection_name}/query", { query_embeddings: [ [0.1, 0.2, 0.3], [0.4, 0.5, 0.6] ] })
    end

    private

    def get_collection(name)
      get("api/v1/collections/#{name}")
    end

    def get_collections
      get("api/v1/collections")
    end

    def get(path)
      HTTParty.get(url(path), headers: { "Content-Type" => "application/json" })
    end

    def post(path, body = {})
      puts body
      HTTParty.post(url(path), headers: { "Content-Type" => "application/json" }, body: body.to_json)
    end

    def url(path)
      "#{@url}/#{path}"
    end
  end
end
