# frozen_string_literal: true

module Retrieval
  # The result of reading part of a document: which part, out of how much, and
  # whether it could be read at all.
  #
  # `refusal` carries the three ways a read comes back with nothing, and they
  # are kept apart for the same reason Outcome keeps empty and failed apart — a
  # model told "nothing" will report an empty archive. A document that hasn't
  # finished processing has text coming; one outside the corpus never will; a
  # range past the end is the model's own slip and is the one it can fix.
  #
  # Deliberately not a Failure: those are infrastructure ("the embedding server
  # didn't answer"), and these are all facts about the archive.
  Reading = Data.define(:document, :from, :to, :total, :hits, :refusal) do
    def initialize(document: nil, from: nil, to: nil, total: nil, hits: [], refusal: nil)
      super
    end

    def self.refused(refusal, document: nil, total: nil)
      new(refusal:, document:, total:)
    end

    def refused? = !refusal.nil?

    # More document sits past what was returned, so the model can ask again
    # from `to + 1` rather than assuming it has seen the lot.
    def more? = !refused? && to < total
  end
end
