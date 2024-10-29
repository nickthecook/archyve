module LlmClients
  module Ollama
    # rubocop:disable Metrics/ClassLength
    class Client < LlmClients::Client
      NETWORK_TIMEOUT = 8

      def complete(prompt, traceable: nil, &block)
        req = helper.completion_request(prompt)

        stream(req, traceable:, &block)
      end

      def chat(message, traceable: nil, &block)
        # Ollama chat protocol matches the one for OpenAI, so use the same helper
        req = helper.chat_request(Openai::ChatMessageHelper.new(message).chat_history, &block)

        stream(req, traceable:, &block)
      end

      def chat_raw(message_list, traceable: nil, &block)
        req = helper.raw_chat_request(message_list, &block)

        stream(req, traceable:, &block)
      end

      def embed(content, traceable: nil)
        req = helper.embed_request(content)

        request(req, traceable:)
      end

      def image(prompt, images:, traceable: nil, &block)
        req = helper.image_request(prompt, images:)

        stream(req, traceable:, &block)
      end

      def list_models(traceable: nil)
        req = helper.list_request

        request(req, traceable:)
      end

      private

      def helper
        @helper ||= RequestHelper.new(@endpoint, @api_key, @embedding_model, @model, @temperature)
      end

      # rubocop:disable all
      def stream(req, traceable: nil, &block)
        response_contents = ""

        Rails.logger.info("Sending request body:\n#{req.body}")
        # TODO: switch to HTTParty for this?
        # TODO: create ApiCall early and update response body after streaming is done
        @stats = new_stats
        full_response = Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https") do |http|
          http.request(req) do |response|
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

        store_api_call("ollama", req, full_response, response_contents, traceable:)

        full_response.body
      end

      def request(request, traceable: nil)
        @stats = new_stats

        response = with_retries do
          response = Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https") do |http|
            http.request(request)
          end
          Rails.logger.info("#{request.method} #{request.uri} ==> #{response.code}")

          # sometimes ollama just returns a 500 on an embed request when running locally, then is fine
          raise RetryableError if response.code == "500"

          stats[:first_token_time] = current_time
          calculate_stats
          store_api_call("ollama", request, response, traceable:)

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
        response_hash["response"] || response_hash["message"]["content"]
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
