# frozen_string_literal: true

module Retrieval
  # A run of chunks from one document, in document order.
  #
  # **This is where access control is enforced for reading**, and it is the same
  # corpus a search draws on — a document the model could not have found is a
  # document it cannot read, whether it guessed the id or was told one by a
  # document it read earlier. `corpus.documents.find_by` is the whole of it:
  # the id narrows a relation it cannot widen.
  #
  # Ranges are 1-based, matching what documents#show calls the same chunk. The
  # model is working from a search result that said "chunk 12 of 47", and a
  # tool that silently meant something else by 12 would be worse than one that
  # refused.
  class Read
    # A whole document is rarely what's wanted and frequently ruinous — chunks
    # vary in size, so the honest limit is characters and the chunk count is the
    # guard against a thousand tiny ones. Whichever binds first wins, and the
    # reply says where it stopped so the model can carry on from there.
    MAX_CHUNKS = 12
    MAX_CHARACTERS = 20_000

    def initialize(corpus:)
      @corpus = corpus
    end

    # => Reading
    def call(id, from: nil, to: nil)
      document = @corpus.documents.find_by(id:)
      return Reading.refused(:not_found) if document.nil?

      total = document.chunks.count
      return Reading.refused(:not_processed, document:) if total.zero?

      read(document, total, from, to)
    end

    private

    def read(document, total, from, to)
      from = bounded(from, 1)
      return Reading.refused(:out_of_range, document:, total:) if from > total

      chunks = affordable(chunks_between(document, from, last(from, to, total)))
      Reading.new(
        document:, total:, from:,
        to: chunks.last.position + 1,
        hits: chunks.map { Hit.new(chunk: it, document:) }
      )
    end

    # A `to` below `from` is a model slip rather than a request for nothing, so
    # it reads the one chunk it asked to start at instead of coming back empty.
    def last(from, to, total)
      [bounded(to, from + MAX_CHUNKS - 1), from].max.clamp(from, [total, from + MAX_CHUNKS - 1].min)
    end

    def chunks_between(document, from, to)
      document.chunks.where(position: (from - 1)..(to - 1)).to_a
    end

    # Always at least one chunk, however long it is. A document chunked into
    # one enormous block would otherwise read as empty, which is the one answer
    # that isn't true.
    def affordable(chunks)
      budget = MAX_CHARACTERS
      chunks.take_while.with_index do |chunk, index|
        budget -= chunk.content.length
        index.zero? || budget >= 0
      end
    end

    # Models send strings, floats and nulls where the schema says integer.
    def bounded(value, default)
      value.nil? ? default : [value.to_i, 1].max
    end
  end
end
