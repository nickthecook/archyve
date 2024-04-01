module Chromadb
  module Responses
    class Query
      def initialize(body)
        body = JSON.parse(body) if body.is_a?(String)

        @body = body
      end

      def objects
        @objects ||= begin
          objects = []

          ids.each_with_index do |id, idx|
            objects << { id:, metadata: metadatas[idx], document: documents[idx], distance: distances[idx] }
          end

          objects
        end
      end

      def ids
        @ids ||= @body["ids"].first
      end

      def metadatas
        @metadatas ||=  @body["metadatas"].first
      end

      def documents
        @documents ||=  @body["documents"].first
      end

      def distances
        @distances ||=  @body["distances"].first
      end
    end
  end
end
