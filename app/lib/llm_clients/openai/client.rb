require "openai"

module LlmClients
  module Openai
    class Client < LlmClients::Client
      include ChatRequestHelper
      include EmbeddingRequestHelper
      include CompletionRequestHelper

      NETWORK_TIMEOUT = 8

      def complete(prompt, &)
        complete_request(prompt, &)
      end

      def chat(message, &)
        chat_request(ChatMessageHelper.new(message).chat_history, &)
      end

      def embed(content)
        embedding_request(content)
      end

      # Callback for instrumenting request via Faraday middleware used by OpenAI API gem
      def instrument(_name, env)
        tmp = yield
        (api_call_for env).save!
        # TODO: - with streaming enabled, unable to retrieve response body via instrumentation callback
        tmp
      end

      private

      # Clean headers to remove API key
      def clean_headers(headers)
        if (apikey = headers["api-key"])
          headers["api-key"] = "#{apikey.first(3)}*****"
        end
        headers
      end

      # Create an ApiCall based on a Faraday environment for this client
      def api_call_for(env)
        ApiCall.from_faraday(
          client_provider,
          request: {
            http_method: env[:method].downcase,
            url: env[:url],
            headers: clean_headers(env[:request_headers]),
            body: env[:request_body],
          },
          response: {
            headers: env[:response_headers],
            status: env[:response].status,
            body: env[:response].body,
          },
          traceable: @traceable
        )
      end

      def client_provider
        raise UnsupportedServerError, "Override to implement client provider name."
      end

      def chat_client
        raise UnsupportedServerError, "Override to implement client connection."
      end

      def embed_client
        raise UnsupportedServerError, "Override to implement client connection."
      end
    end
  end
end
