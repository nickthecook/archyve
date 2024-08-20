class Embedder
  def initialize(model_config:, traceable: nil)
    @client_helper = Helpers::ModelClientHelper.new(model_config:, traceable:)
  end

  def embed(text, traceable: nil)
    response = client.embed(text, traceable: traceable || @traceable)

    response["embedding"]
  end

  private

  def client
    @client_helper.client
  end
end
