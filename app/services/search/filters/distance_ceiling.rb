module Search
  module Filters
    class DistanceCeiling
      DISTANCE_CEILING = 400

      def initialize(hits)
        @hits = hits

        mark_relevance
      end

      def all
        @hits
      end

      def filtered
        @hits.select(&:relevant)
      end

      private

      def mark_relevance
        @hits.each do |hit|
          hit.relevant = hit.distance <= DISTANCE_CEILING
        end
      end
    end
  end
end
