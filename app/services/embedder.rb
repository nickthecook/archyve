class Embedder
  include Helpers::ModelClient

  def embed(text)
    response = client.embed(text)

    response["embedding"]
  end
end
