# frozen_string_literal: true

module Retrieval
  # One retrieved chunk, and what it took to find it.
  #
  # `handle` is the short label the model cites — "1", "2" — and the only name
  # it is ever given for a source. It cites the handle, Archyve resolves the
  # handle to a link, so the model has no way to author a URL and no way to
  # invent a document. Positional, so it is only meaningful within the result
  # set it was assigned in.
  #
  # Both a distance and a score, because they answer different questions.
  # `distance` is cosine distance from one query vector and is what a person
  # reads as a percentage. `score` is the fused rank across every query in the
  # call and is what the ordering is actually by — see Fuse for why the two
  # can disagree.
  Hit = Data.define(:chunk, :document, :distance, :score, :handle) do
    def initialize(chunk:, document:, distance:, score: nil, handle: nil)
      super
    end

    # Cosine distance (0 identical … 2 opposite) → a friendly percentage.
    def similarity = ((1 - distance) * 100).round.clamp(0, 100)

    def heading_path = Array(chunk.structure["heading_path"]).join(" › ")

    def with_handle(handle) = with(handle:)
  end
end
