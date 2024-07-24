require "openai"

module LlmClients
  module Openai
    module CompletionRequestHelper
      def complete_request(prompt, &)
        messages = []
        messages << { role: "user", content: prompt }

        response = chat_client.chat(
          parameters: {
            model: @model,
            messages:,
            temperature: @temperature,
          })
        yield response.dig("choices", 0, "message", "content")
        response
      end
    end
  end
end
