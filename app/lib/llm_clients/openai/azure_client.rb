require "openai"

module LlmClients
  module Openai
    class AzureClient < Client
      private

      def client_provider
        "openai_azure"
      end

      def chat_connection
        az_openai_connection(@model)
      end

      def embed_connection
        az_openai_connection(@embedding_model)
      end

      def az_openai_connection(model_name)
        @az_openai_connection ||= OpenAI::Client.new(
          access_token: @api_key,
          uri_base: "#{@endpoint}/openai/deployments/#{model_name}",
          api_version: @api_version,
          api_type: :azure
        ) do |f|
          f.request :instrumentation, name: 'req', instrumenter: self
        end
      end
    end
  end
end
