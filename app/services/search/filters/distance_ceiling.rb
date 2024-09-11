module Search
  module Filters
    class DistanceCeiling
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
          hit.relevant = hit.distance <= distance_ceiling
        end
      end

      def distance_ceiling
        Setting.get("normalized_search_distance_ceiling", default: 0.5)
      end
    end
  end
end
