require "openai"

module LlmClients
  module Openai
    module ChatRequestHelper
      def chat_request(chat_history, &)
        @stats = new_stats
        stats[:start_time] = current_time
        num_tokens = 0

        current_batch = ""
        current_batch_size = 0

        resp = chat_client.chat(
          parameters: {
            model: @model,
            messages: chat_history, # Required.
            temperature: @temperature,
            stream: proc do |chunk|
                      if num_tokens.zero?
                        stats[:first_token_time] = current_time
                      end
                      num_tokens += 1
                      unless (str = chunk.dig("choices", 0, "delta", "content")).nil?
                        current_batch << str
                        current_batch_size += 1
                        if str.ends_with?("\n") || str.ends_with?("}") || current_batch_size >= @batch_size
                          Rails.logger.debug { "==> #{current_batch}" }
                          yield current_batch

                          current_batch_size = 0
                          current_batch = ""
                        end
                      end
                    end,
          })

        if current_batch_size.positive?
          Rails.logger.debug { "==> #{current_batch}" }
          yield current_batch
        end

        stats[:tokens] = num_tokens
        calculate_stats

        resp
      end
    end
  end
end
