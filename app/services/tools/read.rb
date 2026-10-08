# frozen_string_literal: true

module Tools
  # Read a run of chunks from one document the model has already been shown.
  #
  # Search finds the passage that mentions the thing; often the sentence that
  # *answers* the question is in the chunk after it. Without this the model can
  # only search again with different words and hope the neighbour surfaces.
  #
  # ## A refusal says as little as possible
  #
  # `document` is an id, so the model can put any integer there — including one
  # it invented, or one an ingested document told it to try. Three situations
  # come back identically: no such document, a document in a collection this
  # reader was never granted, and a document they may read but this chat isn't
  # scoped to. Telling them apart would turn a guessed id into an enumeration
  # oracle — a way to count what exists behind grants the reader doesn't hold.
  # Retrieval::Scope drops an unreadable collection slug for the same reason.
  class Read < Base
    def name = "read_document"

    params do
      integer :document,
        description: "The id of the document to read, exactly as a search result gave it."
      integer :from,
        description: "First chunk to return, counting from 1. Defaults to the start of the document.",
        required: false
      integer :to,
        description: "Last chunk to return. Defaults to a page of #{Retrieval::Read::MAX_CHUNKS} chunks.",
        required: false
    end

    def description
      <<~TEXT.strip
        Read a document from #{scope_label} in full or in part, by the id a search result gave
        you. Use it when a result looks right but stops short — a search result says which
        chunk it is and how many the document has, so ask for a few either side of it. You
        can only read documents you have already been shown the id of.
      TEXT
    end

    def execute(document:, from: nil, to: nil)
      return budget_spent("read a document") if over_budget?

      spend_round
      observer&.reading_started(document)
      reading = handled(Retrieval::Read.new(corpus:).call(document, from:, to:))
      observer&.reading_finished(reading)

      respond(reading)
    end

    private

    def default_max_rounds = Setting.chat_max_read_rounds

    # One handle namespace for the whole turn, stamped before the observer sees
    # the reading so the transcript and the model cite the same numbers.
    def handled(reading)
      return reading if reading.refused?

      reading.with(hits: handles.assign(reading.hits))
    end

    def respond(reading)
      return refusal(reading) if reading.refused?

      {
        status: "ok",
        id: reading.document.id,
        document: reading.document.title,
        chunks: { from: reading.from, to: reading.to, total: reading.total },
        passages: reading.hits.map { passage_for(it) }
      }.merge(more(reading))
    end

    def passage_for(hit)
      {
        handle: hit.handle,
        chunk: hit.chunk.position + 1,
        section: hit.heading_path.presence,
        text: hit.chunk.content
      }.compact
    end

    # Said only when it is true. A model told every time that more might remain
    # learns to ignore it, and the one reading that really was cut off is the
    # one where it matters.
    def more(reading)
      return {} unless reading.more?

      remaining = reading.total - reading.to
      {
        instruction: "#{remaining} more #{'chunk'.pluralize(remaining)} follow. Call read_document " \
                     "again with from: #{reading.to + 1} if you need them."
      }
    end

    def refusal(reading)
      case reading.refusal
      when :not_found then not_found
      when :not_processed then not_processed(reading)
      else out_of_range(reading)
      end
    end

    # Deliberately incurious about why. See the note at the top of this class.
    def not_found
      {
        status: "not_found",
        instruction: "No such document in #{scope_label}. Only read ids that search_archive gave " \
                     "you, and do not tell the user a document exists that you could not read."
      }
    end

    # Text is coming, just not yet — which is a different thing to tell someone
    # than "there is nothing there", and the difference is the whole reason
    # this isn't folded into not_found.
    def not_processed(reading)
      {
        status: "not_processed",
        id: reading.document.id,
        document: reading.document.title,
        instruction: "This document is in the archive but hasn't been processed yet, so it has no " \
                     "text to read. Say so rather than answering from your own knowledge."
      }
    end

    def out_of_range(reading)
      {
        status: "out_of_range",
        id: reading.document.id,
        document: reading.document.title,
        chunks: { total: reading.total },
        instruction: "That document has #{reading.total} #{'chunk'.pluralize(reading.total)}. " \
                     "Call read_document again with a range inside it."
      }
    end
  end
end
