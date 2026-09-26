# frozen_string_literal: true

module Retrieval
  # One chunk the model was shown, and what it took to put it there.
  #
  # `handle` is the short label the model cites — "1", "2" — and the only name
  # it is ever given for a *passage*. It cites the handle, Archyve resolves the
  # handle to a link, so the model has no way to author a URL and no way to
  # cite a passage it was never shown. Assigned per turn by Retrieval::Handles,
  # and meaningless outside it.
  #
  # Both a distance and a score, because they answer different questions.
  # `distance` is cosine distance from one query vector and is what a person
  # reads as a percentage. `score` is the fused rank across every query in the
  # call and is what the ordering is actually by — see Fuse for why the two
  # can disagree.
  #
  # Both are absent on a chunk that was *read* rather than found (Retrieval::
  # Read): nothing ranked it, and a zero there would render as a relevance
  # reading nobody took.
  Hit = Data.define(:chunk, :document, :distance, :score, :handle) do
    def initialize(chunk:, document:, distance: nil, score: nil, handle: nil)
      super
    end

    # Cosine distance (0 identical … 2 opposite) → a friendly percentage.
    def similarity = distance && ((1 - distance) * 100).round.clamp(0, 100)

    def heading_path = Array(chunk.structure["heading_path"]).join(" › ")

    def with_handle(handle) = with(handle:)
  end
end
