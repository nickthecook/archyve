module LlmClients
  module Ollama
    class ModelInfo
      DEFAULT_CONTEXT_SIZE = 2048
      DEFAULT_TEMPERATURE = 0.8

      attr_reader :name, :model

      def initialize(name, model, model_info)
        @name = name
        @model = model
        @model_info = model_info
      end

      def context_window_size
        @context_window_size ||= extract_parameter("num_ctx")&.to_i || DEFAULT_CONTEXT_SIZE
      end

      def temperature
        @temperature || extract_parameter("temperature")&.to_f || DEFAULT_TEMPERATURE
      end

      private

      def extract_parameter(param)
        modelfile.each_line do |line|
          match = line.match(/^PARAMETER +#{param} +(\s+)/)&.captures
          return match if match
        end

        nil
      end

      def modelfile
        @model_info["modelfile"]
      end
    end
  end
end
