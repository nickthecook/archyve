require "openai"

module LlmClients
  module Openai
    module EmbeddingRequestHelper
      def embedding_request(content)
        response = embed_client.embeddings(
          parameters: {
            model: @embedding_model,
            input: content,
          }
        )
        { "embedding" => response.dig("data", 0, "embedding") }
      end
    end
  end
end
