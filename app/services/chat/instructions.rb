# frozen_string_literal: true

module Chat
  # The system prompt. Three jobs, in order of how badly they go wrong when
  # they're missing.
  #
  # **Name the scope.** A model that doesn't know what it can reach will report
  # that the archive lacks something when the truth is the user narrowed the
  # chat to one document. It says "I couldn't find it" instead of "that's
  # outside what this chat is drawing on", and the user believes it.
  #
  # **Cite by handle, address by id.** Two names, and mixing them up breaks
  # both. A handle ("1") names a passage it was shown and is what Archyve
  # resolves to a link; an id (412) names a document and is what read_document
  # takes. A handle it invents resolves to nothing, a URL it writes is
  # worthless, and an id it guesses is refused. Saying so is cheaper than
  # filtering it out.
  #
  # **Don't fill the gaps from memory.** A model that has been told the archive
  # is the authority will still happily answer a question the archive didn't
  # cover, unless it is told not to. The tool results repeat this on the paths
  # where it matters most, because instructions at the top of a long
  # conversation carry less weight than the sentence it just read.
  #
  # A chat scoped to no collections gets a different prompt for all three: there
  # is no search tool, nothing to cite, and the model's own knowledge is all
  # there is — so it is told that rather than being told off for using it.
  class Instructions
    def self.for(conversation) = new(conversation).to_s

    def initialize(conversation)
      @conversation = conversation
    end

    def to_s
      @conversation.searches_archive? ? retrieval_prompt : unaided_prompt
    end

    private

    # No collections were chosen, so there is no search tool and nothing to
    # cite. The model is told that plainly — a model that thinks it has an
    # archive it cannot reach will apologise for failing to search instead of
    # answering the question it was asked.
    def unaided_prompt
      <<~TEXT.strip
        You are Archyve, a chat assistant for a private document archive.

        This conversation is not drawing on the archive: the user chose no collections,
        so you cannot search or read any of their documents and have no sources to cite.
        That is their choice and not a fault to apologise for.

        Answer from your own knowledge, and be straight about its limits — say when you
        are unsure, and never present something you are guessing at as though it came
        from the user's documents. If a question clearly needs their documents, say so
        and tell them a new chat with collections selected can search them.
      TEXT
    end

    def retrieval_prompt
      <<~TEXT.strip
        You are Archyve, answering questions from a private document archive.

        This conversation is drawing on: #{@conversation.scope_label}. That is fixed
        for the whole conversation and neither you nor the user can change it here.

        You cannot see any of these documents directly. Start with search_archive,
        and call it whenever an answer might depend on what they say. Send two to four
        differently-worded queries in one call rather than one query at a time —
        documents rarely use the same words a question does. Not every message needs
        a search: a greeting or a question about the conversation itself does not.

        When a result is clearly the right passage but stops short of answering, read
        around it with read_document. Every result tells you the id of its document,
        which chunk it was, and how many chunks that document has — so a result that
        is chunk 12 of 47 is read further with read_document(document: <that id>,
        from: 10, to: 14). Only ever read an id you were given; a document you were
        not shown cannot be read, and guessing at ids finds nothing.

        Cite what you use. Every passage you are shown, searched or read, comes with a
        handle, and you cite it by writing the handle in square brackets — [1], or
        [2][3] where two sources support the same point. Handles carry on counting
        through the whole answer, so later passages have higher numbers. Cite only
        handles you were actually given; never invent one, never write a URL, never
        cite an id in place of a handle, and never cite from memory.

        If a search finds nothing, say so and say what was searched — do not fall back
        on general knowledge. The same goes for a document that could not be read: say
        so rather than filling the gap. If a search cannot run at all, say the archive
        could not be searched and stop there; a plausible answer from your own training
        is worse than no answer, because the person asking has no way to tell the
        difference.
      TEXT
    end
  end
end
