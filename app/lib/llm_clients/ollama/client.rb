module LlmClients
  module Ollama
    class Client < LlmClients::Client
      NETWORK_TIMEOUT = 8

      def complete(prompt, &)
        request = helper.completion_request(prompt)

        stream(request, &)
      end

      def chat(chat, &)
        request = helper.chat_request(chat.chat_history)

        stream(request, &)
      end

      def embed(content)
        request = helper.embed_request(content)

        request(request)
      end

      private

      def helper
        @helper ||= RequestHelper.new(@endpoint, @api_key, @embedding_model, @model, @temperature)
      end

      # rubocop:disable all
      def stream(request, &block)
        @stats = new_stats

        response_contents = ""

        Rails.logger.info("Sending request body:\n#{request.body}")
        # TODO: switch to HTTParty for this?
        # TODO: create ApiCall early and update response body after streaming is done
        full_response = Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https") do |http|
          stats[:start_time] = current_time
          http.request(request) do |response|
            raise response_error_for(response) unless response.is_a?(Net::HTTPSuccess)

            stats[:first_token_time] = current_time

            current_chunk = ""
            current_batch = ""
            current_batch_size = 0

            response.read_body do |chunk|
              current_chunk << chunk
              next unless current_chunk.ends_with?("\n") || current_chunk.ends_with?("}")

              message = extract_message(current_chunk)
              current_batch << message
              current_chunk = ""
              stats[:tokens] += 1
              current_batch_size += 1

              if current_batch_size == @batch_size
                Rails.logger.debug "==> #{current_batch}"
                response_contents << current_batch
                yield current_batch if block_given?

                current_batch_size = 0
                current_batch = ""
              end
            end

            if current_batch_size > 0
              Rails.logger.debug "==> #{current_batch}"
              response_contents << current_batch
              yield current_batch if block_given?
            end

            calculate_stats
          end
        end

        store_api_call("ollama", request, full_response, response_contents)

        full_response.body
      end

      def request(request)
        response = with_retries do
          response = Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https") do |http|
            http.request(request)
          end
          Rails.logger.info("#{request.method} #{request.uri} ==> #{response.code}")

          # sometimes ollama just returns a 500 on an embed request when running locally, then is fine
          raise RetryableError if response.code == "500"

          store_api_call("ollama", request, response)
          response
        end

        raise response_error_for(response) unless response.kind_of?(Net::HTTPSuccess)

        parse_response(response)
      rescue SocketError
        raise ResponseError.new("Unable to connect to the active server", [ModelServer.active_server.url])
      end
      # rubocop:enable all

      def parse_response(http_response)
        JSON.parse(http_response.body)
      rescue JSON::ParserError
        http_response.body
      end

      def extract_message(response_string)
        response_hash = JSON.parse(response_string)
        message = response_hash["response"] || response_hash["message"]["content"]
        Rails.logger.debug { "<== '#{message}'" }

        message
      end

      def template_for(model)
        MODEL_TEMPLATE_MAP.each do |name, template|
          if model =~ Regexp.new(name)
            return template
          end
        end

        { prefix: "", suffix: "" }
      end
    end
  end
end
