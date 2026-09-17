class AddGenerationPaceToSegments < ActiveRecord::Migration[8.1]
  def change
    # How fast the model produced this segment. Two facts rather than a rate, so
    # the number can be recomputed if we ever change our mind about how to
    # present it, and so a segment that is still streaming can hold a partial
    # count without also holding a misleading rate.
    #
    # The span starts at the *first* delta, not at the request: everything
    # before that is the model reading the prompt, and a long conversation
    # would otherwise make a fast model look slow. See Chat::Pace.
    #
    # Nullable, and null on every row that exists today. A segment from before
    # this was recorded has no rate rather than a rate of zero, and the views
    # render nothing at all in that case.
    add_column :segments, :token_count, :integer
    add_column :segments, :generation_ms, :integer
  end
end
