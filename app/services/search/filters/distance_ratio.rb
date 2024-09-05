module Search
  module Filters
    class DistanceRatio
      def initialize(hits)
        @hits = hits

        mark_previous_distances
        mark_relevance
      end

      def all
        @hits
      end

      def filtered
        @hits.select(&:relevant)
      end

      private

      def mark_previous_distances
        previous = nil
        @hits.each do |hit|
          hit.previous_distance = previous

          previous = hit.distance
        end
      end

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
        @distance_ratio_threshold || Setting.get("distance_ratio_threshold", default: 0.2)
      end
    end
  end
end
