module LlmClients
  module Formatters
    class Granite
      def format(string)
        string.gsub(/\n\s+```/, "")
      end
    end
  end
end
