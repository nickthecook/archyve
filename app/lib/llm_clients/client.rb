module LlmClients
  # rubocop:disable Metrics/ClassLength
  class Client
    MODEL_TEMPLATE_MAP = {
      "^gemma:" => { prefix: "<start_of_turn>user\n", suffix: "<end_of_turn>\n<start_of_turn>model" },
      "^mi[xs]tral:" => { prefix: "<s>[INST]", suffix: "[/INST] " },
      "^granite-code:" => { prefix: "<|user|>", suffix: "<|assistant|>" },
    }.freeze
    TIMEOUT_RETRIES = 3
    FORMATTERS = {
      "^granite-code:" => Formatters::Granite,
      "^mistral:" => Formatters::Mistral,
    }.freeze

    attr_reader :stats

    class << self
      def client_class_for(provider)
        return LlmClients::Ollama::Client if provider == "ollama"

        raise UnsupportedServerError, "Only 'ollama' is supported. You asked for '#{provider}'."
      end
    end

    def initialize(
      endpoint:,
      api_key:,
      model: nil,
      embedding_model: nil,
      temperature: default_temperature,
      batch_size: default_batch_size
    )
      @endpoint = endpoint
      @api_key = api_key
      @model = model
      @embedding_model = embedding_model
      @temperature = temperature
      @batch_size = batch_size

      @uri = URI(endpoint)
    end

    private

    def context(prompt, model)
      template = template_for(model)

      "#{template[:prefix]}#{prompt}#{template[:suffix]}"
    end

    def template_for(model)
      MODEL_TEMPLATE_MAP.each do |name, template|
        if model =~ Regexp.new(name)
          return template
        end
      end

      { prefix: "", suffix: "" }
    end

    def response_error_for(response)
      additional_info = [response.uri]

      error = begin
        JSON.parse(response.body)[response_error_field]
      rescue JSON::ParserError
        nil
      end
      additional_info.append(error) if error

      ResponseError.new(
        "Server responded with #{response.code}: #{response.message}", additional_info
      )
    end

    def response_error_field
      "error"
    end

    def new_stats
      {
        start_time: nil,
        end_time: nil,
        elapsed_ms: nil,
        tokens: 0,
        tokens_per_sec: nil,
        time_to_first_token: nil,
      }
    end

    def calculate_stats
      @stats[:end_time] = current_time
      elapsed_s = (@stats[:end_time] - @stats[:start_time])
      @stats[:elapsed_ms] = (elapsed_s * 1000).to_i
      @stats[:tokens_per_sec] = (@stats[:tokens] / elapsed_s).round(2)
      @stats[:time_to_first_token] = (@stats[:first_token_time] - @stats[:start_time]).round(3)
    end

    def default_temperature
      0.1
    end

    def default_batch_size
      256
    end

    def current_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def with_retries
      retries = 0
      exception = nil
      while retries <= TIMEOUT_RETRIES
        begin
          return yield
        rescue Net::OpenTimeout, Net::ReadTimeout, RetryableError => e
          exception = e
          retries += 1
          Rails.logger.warn("Attempt #{retries}/#{TIMEOUT_RETRIES} failed: #{e.class.name}")
        end
      end

      Rails.logger.error("Retries exhausted (#{retries}/#{TIMEOUT_RETRIES})")
      raise exception
    end
  end
  # rubocop:enable Metrics/ClassLength
end
