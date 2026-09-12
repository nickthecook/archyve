# frozen_string_literal: true

module Retrieval
  # The result of a retrieval: what was found, how wide the net was, and
  # whether it ran at all.
  #
  # **Empty and failed are not the same outcome**, and collapsing them is the
  # bug this type exists to prevent. A page can afford to render both as "no
  # results"; a model cannot. Handed an empty list, it will tell someone their
  # archive doesn't contain the thing they asked about — confidently, and
  # wrongly, when the truth is that the embedding server was down.
  #
  # `candidate_count` is the pool the top hits were chosen from: every distinct
  # chunk any of the queries surfaced, before fusion truncated it. It's what
  # lets the collapsed retrieval panel say "6 of 41" and give some sense of
  # whether retrieval was spoiled for choice or scraping.
  Outcome = Data.define(:hits, :candidate_count, :failure) do
    def initialize(hits: [], candidate_count: 0, failure: nil)
      super
    end

    def self.failed(kind, server_name: nil, model_name: nil)
      new(failure: Failure.new(kind:, server_name:, model_name:))
    end

    def failed? = !failure.nil?
    def empty? = hits.empty?

    # True only when retrieval ran and found nothing — the honest "your archive
    # doesn't cover this" that a failure must never be mistaken for.
    def found_nothing? = !failed? && hits.empty?
  end
end
