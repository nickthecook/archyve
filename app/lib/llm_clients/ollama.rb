require_relative "common"

module LlmClients
  class Ollama < Client
    NETWORK_TIMEOUT = 8

    # rubocop:disable all
    def complete(prompt, &block)
      @stats = new_stats
      request = completion_request(prompt)

      # TODO: switch to HTTParty for this?
      Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https") do |http|
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
              yield current_batch

              current_batch_size = 0
              current_batch = ""
            end
          end

          if current_batch_size > 0
            Rails.logger.debug "==> #{current_batch}"
            yield current_batch
          end

          calculate_stats
        end
      end
    end
    # rubocop:enable all

    def embed(prompt)
      response = with_retries do
        HTTParty.post(uri(embedding_path), headers:, timeout: NETWORK_TIMEOUT, body: {
          model: embedding_model,
          prompt:
        }.to_json)
      end

      raise response_error_for(response) unless response.success?

      response.parsed_response
    end

    private

    def completion_request(prompt)
      request = Net::HTTP::Post.new(uri(completion_path), **headers)
      request.body = {
        model: @model,
        prompt:,
        temperature: @temperature,
        stream: true,
        max_tokens: 200
      }.to_json

      request
    end

    def extract_message(response_string)
      response_hash = JSON.parse(response_string)
      message = response_hash["response"]
      Rails.logger.debug("<== '#{message}'")

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

    def completion_path
      "/api/generate"
    end

    def embedding_path
      "/api/embeddings"
    end

    def embedding_model
      Rails.configuration.embedding_model
    end
  end
end
