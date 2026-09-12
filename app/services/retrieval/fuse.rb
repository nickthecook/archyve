# frozen_string_literal: true

module Retrieval
  # Merges the results of several queries into one ranking, by reciprocal rank
  # fusion: a chunk scores `1 / (K + rank)` in each list it appears in, and its
  # scores add up.
  #
  # ## Why not just sort by distance
  #
  # Because distances from different query vectors aren't comparable. A query
  # that happens to land near the middle of the corpus scores better against
  # everything, and sorting the merged pile by raw distance lets it crowd the
  # other queries out of the top slots entirely — which defeats the point of
  # letting the model ask three different things. RRF only ever compares a
  # chunk to the other chunks *its own* query returned, so each query gets a
  # fair say, and a chunk that several queries agree on rises above one that
  # only one query loved.
  #
  # K damps the top of each list: without it the rank-1 chunk of one query
  # outweighs the rank-1 and rank-2 of another combined. 60 is the value from
  # the paper the technique comes from (Cormack, Clarke & Buettcher, 2009) and
  # there is no reason to have an opinion about it until retrieval quality says
  # otherwise.
  class Fuse
    K = 60

    # ranked_lists: Array<Array<Embedding>>, each already in relevance order.
    # => Array<Hit>, best first, handles assigned 1..n in final order.
    def self.call(ranked_lists, limit:)
      new(ranked_lists).call(limit:)
    end

    def initialize(ranked_lists)
      @ranked_lists = ranked_lists
    end

    def call(limit:)
      scored
        .sort_by { |_chunk_id, entry| [-entry[:score], entry[:distance]] }
        .first(limit)
        .each_with_index
        .map { |(_chunk_id, entry), index| hit(entry, index + 1) }
    end

    private

    # chunk_id => { embedding:, score:, distance: }. The retained distance is
    # the best any query achieved, since that's the one worth showing.
    def scored
      @ranked_lists.each_with_object({}) do |embeddings, totals|
        embeddings.each_with_index do |embedding, index|
          entry = totals[embedding.chunk_id] ||= { embedding:, score: 0.0, distance: Float::INFINITY }
          entry[:score] += 1.0 / (K + index + 1)
          next unless embedding.neighbor_distance < entry[:distance]

          entry[:distance] = embedding.neighbor_distance
          entry[:embedding] = embedding
        end
      end
    end

    def hit(entry, handle)
      chunk = entry[:embedding].chunk
      Hit.new(chunk:, document: chunk.document, distance: entry[:distance], score: entry[:score], handle:)
    end
  end
end
