require "openai"

module LlmClients
  module Openai
    #rubocop:disable Metrics/ClassLength
    class Client < LlmClients::Client
      NETWORK_TIMEOUT = 8

      def complete(prompt, traceable: nil, &block)
        @per_request_traceable = traceable

        complete_request(prompt, &block)
      end

      def chat(message, traceable: nil, &block)
        @per_request_traceable = traceable

        chat_request(ChatMessageHelper.new(message).chat_history, &block)
      end

      def embed(content, traceable: nil)
        @per_request_traceable = traceable

        embedding_request(content)
      end

      # Callback for instrumenting request via Faraday middleware used by OpenAI API gem
      def instrument(_name, env, &)
        begin
          response = yield
        # Faraday doesn't populate response code on errors...
        rescue Faraday::ResourceNotFound => e
          api_call_for(env, traceable: @per_request_traceable || @traceable, status: 404).save!

          raise e
        rescue Faraday::TooManyRequestsError
          api_call_for(env, traceable: @per_request_traceable || @traceable, status: 429).save!

          raise RetryableError if response.code == 429
        end

        api_call_for(env, traceable: @per_request_traceable || @traceable).save!
        @per_request_traceable = nil

        # TODO: - with streaming enabled, unable to retrieve response body via instrumentation callback
        response
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
      def api_call_for(env, traceable:, status: nil)
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
            status: status || env[:response].status,
            body: env[:response].body,
          },
          traceable:
        )
      end

      # rubocop:disable all
      def chat_request(chat_history, &)
        @stats = new_stats
        stats[:start_time] = current_time
        num_tokens = 0

        current_batch = ""
        current_batch_size = 0

        resp = with_retries do
          chat_connection.chat(
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
                  yield current_batch if block_given?

                  current_batch_size = 0
                  current_batch = ""
                end
              end
            end,
          })
        end

        if current_batch_size.positive?
          Rails.logger.debug { "==> #{current_batch}" }
          yield current_batch if block_given?
        end

        stats[:tokens] = num_tokens
        calculate_stats

        resp
      end
      # rubocop:enable all

      def complete_request(prompt, &)
        @stats = new_stats
        stats[:start_time] = current_time
        messages = []
        messages << { role: "user", content: prompt }

        response = with_retries do
          chat_connection.chat(
            parameters: {
              model: @model,
              messages:,
              temperature: @temperature,
            }
          )
        end
        stats[:first_token_time] = current_time

        reply = response.dig("choices", 0, "message", "content")

        yield reply if block_given?

        stats[:tokens] = response.dig("usage", "total_tokens")
        calculate_stats

        reply
      end

      def embedding_request(content)
        response = with_retries do
          embed_connection.embeddings(
            parameters: {
              model: @embedding_model,
              input: content,
            }
          )
        end
        { "embedding" => response.dig("data", 0, "embedding") }
      end

      def client_provider
        raise UnsupportedServerError, "Override to implement client provider name."
      end

      def chat_connection
        raise UnsupportedServerError, "Override to implement client connection."
      end

      def embed_connection
        raise UnsupportedServerError, "Override to implement client connection."
      end
    end
    #rubocop:enable Metrics/ClassLength
  end
end
