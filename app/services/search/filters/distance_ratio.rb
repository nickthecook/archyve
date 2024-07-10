module Search
  module Filters
    class DistanceRatio
      DISTANCE_RATIO_THRESHOLD = 0.2

      attr_reader :hits

      def initialize(hits)
        @hits = hits

        mark_relevance
      end

      def filtered
        @hits.select(&:relevant)
      end

      private

      def mark_relevance
        still_relevant = true

        @hits.each do |hit|
          if still_relevant && hit.distance_increase_ratio > distance_ratio_threshold
            still_relevant = false
          end

          hit.relevant = still_relevant
        end
      end

      def distance_ratio_threshold
        @distance_ratio_threshold || Setting.get("distance_ratio_threshold", default: DISTANCE_RATIO_THRESHOLD)
      end
    end
  end
end
