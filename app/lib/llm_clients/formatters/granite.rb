module LlmClients
  module Formatters
    class Granite
      def format(string)
        string.gsub(/\s+```/, "")
      end
    end
  end
end
