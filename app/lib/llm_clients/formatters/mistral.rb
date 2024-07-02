module LlmClients
  module Formatters
    class Mistral
      def format(string)
        string.gsub(/\s+```/, "")
      end
    end
  end
end
