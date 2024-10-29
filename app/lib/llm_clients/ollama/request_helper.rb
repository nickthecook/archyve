module LlmClients
  module Ollama
    class RequestHelper
      def initialize(endpoint, api_key, embedding_model, model, temperature)
        @endpoint = endpoint
        @api_key = api_key
        @embedding_model = embedding_model
        @model = model
        @temperature = temperature
      end

      def embed_request(content)
        request = Net::HTTP::Post.new(uri(embedding_path), **headers)
        request.body = { model: @embedding_model, prompt: content }.to_json

        request
      end

      def completion_request(prompt)
        request = Net::HTTP::Post.new(uri(completion_path), **headers)
        request.body = { model: @model, prompt:, temperature: @temperature, stream: true, max_tokens: 200 }.to_json

        request
      end

      def chat_request(messages)
        request = Net::HTTP::Post.new(uri(chat_path), **headers)
        request.body = { model: @model, messages: }.to_json

        request
      end

      # Make a request with a `prompt` and one or more `images` supplied as an array of base-64-encoded
      # strings of the raw image files (e.g. PNG, JPG)
      def image_request(prompt, images:, max_tokens: 200)
        request = Net::HTTP::Post.new(uri(completion_path), **headers)
        request.body = { model: @model, prompt:, images:, temperature: @temperature, stream: true, max_tokens: }.to_json

        request
      end

      def raw_chat_request(message_list)
        chat = { model: @model, messages: message_list }

        request = Net::HTTP::Post.new(uri(chat_path), **headers)
        request.body = chat.to_json

        request
      end

      def list_request
        Net::HTTP::Get.new(uri(tags_path), **headers)
      end

      def model_info_request(name)
        request = Net::HTTP::Post.new(uri(model_info_path))
        request.body = { "name" => name }.to_json

        request
      end

      private

      def uri(path)
        URI("#{@endpoint}#{"/" unless path.starts_with?("/") || @endpoint.ends_with?("/")}#{path}")
      end

      def headers
        headers = { "Content-Type": "application/json" }
        headers[:Authorization] = "Bearer #{@api_key}" if @api_key

        headers
      end

      def completion_path
        "api/generate"
      end

      def embedding_path
        "api/embeddings"
      end

      def chat_path
        "api/chat"
      end

      def tags_path
        "api/tags"
      end

      def model_info_path
        "api/show"
      end
    end
  end
end
