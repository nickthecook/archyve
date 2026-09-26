# frozen_string_literal: true

module Retrieval
  # The citation handles for one turn, in one namespace.
  #
  # Positional per search was enough while a turn could only search: the model
  # saw one block of results and cited into it. Now a turn can search twice and
  # read as well, and numbering that restarts at 1 in every block means "[2]"
  # names three different passages in the same answer — the model can't cite
  # unambiguously and the transcript can't resolve what it wrote.
  #
  # So handles count on for the whole turn: 1-6 from the first search, 7-12
  # from the second, 13 on from a read.
  class Handles
    def initialize = @last = 0

    def assign(hits)
      hits.map { it.with_handle(@last += 1) }
    end
  end
end
