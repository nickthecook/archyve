module LlmClients
  module Ollama
    class ModelDetails
      DEFAULT_CONTEXT_SIZE = 2048
      DEFAULT_TEMPERATURE = 0.8

      EMBEDDING_MODEL_REGEX = /(nomic|minilm|bert)/i

      attr_reader :name, :model

      def initialize(name, model, model_details)
        @name = name
        @model = model
        @model_details = model_details
      end

      def context_window_size
        @context_window_size ||= extract_parameter("num_ctx")&.to_i || DEFAULT_CONTEXT_SIZE
      end

      def temperature
        @temperature || extract_parameter("temperature")&.to_f || DEFAULT_TEMPERATURE
      end

      def embedding?
        @model_details.dig("model_info", "general.architecture").match?(EMBEDDING_MODEL_REGEX)
      end

      def vision?
        @model_details.keys.include?("projector_info")
      end

      private

      def extract_parameter(param)
        modelfile.each_line do |line|
          match = line.match(/^PARAMETER +#{param} +(\S+)/)&.captures&.first
          return match if match
        end

        nil
      end

      def modelfile
        @model_details["modelfile"]
      end
    end
  end
end
