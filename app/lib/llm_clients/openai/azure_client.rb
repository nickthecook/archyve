require "openai"

module LlmClients
  module Openai
    class AzureClient < Client
      private

      def client_provider
        "openai_azure"
      end

      def chat_client
        az_client(@model)
      end

      def embed_client
        az_client(@embedding_model)
      end

      def az_client(model_name)
        @az_client ||= OpenAI::Client.new(
          access_token: @api_key,
          uri_base: "#{@endpoint}/deployments/#{model_name}",
          api_version: @api_version,
          api_type: :azure
        ) do |f|
          f.request :instrumentation, name: 'req', instrumenter: self
        end
      end
    end
  end
end
