# frozen_string_literal: true

module Toolsets
  # The rules the archive tools depend on. See "The system prompt" in
  # docs/architecture.md for why each one is there.
  class Archive < Base
    def self.label = "Archive"
    def self.description = "Search, read and list the collections a conversation draws on."
    def self.role_floor = :visitor

    def instructions
      @conversation.searches_archive? ? retrieval : unaided
    end

    # A chat scoped to no collections gets none: tools that could only come back
    # empty would have the model reporting an empty archive.
    #
    # One corpus and one handle counter for the whole turn: the corpus so the
    # tools can't disagree about what this conversation can see, the counter so
    # they cite into one namespace.
    def tools(observer:)
      return [] unless @conversation.searches_archive?

      shared = { corpus: Retrieval::Corpus.for(@conversation), handles: Retrieval::Handles.new, observer: }
      [
        Tools::Search.new(limit: Setting.chat_result_limit, **shared),
        Tools::Read.new(**shared),
        Tools::ListCollections.new(**shared),
        Tools::ListDocuments.new(**shared)
      ]
    end

    private

    def unaided
      <<~TEXT.strip
        This conversation is not drawing on the archive: the user chose no collections,
        so you cannot search or read any of their documents and have no sources to cite.
        That is their choice and not a fault to apologise for.

        Answer from your own knowledge, and be straight about its limits — say when you
        are unsure, and never present something you are guessing at as though it came
        from the user's documents. If a question clearly needs their documents, say so
        and tell them a new chat with collections selected can search them.
      TEXT
    end

    def retrieval
      <<~TEXT.strip
        This conversation is drawing on: #{@conversation.scope_label}. That is fixed
        for the whole conversation and neither you nor the user can change it here.

        You cannot see any of these documents directly. Start with search_archive,
        and call it whenever an answer might depend on what they say. Send two to four
        differently-worded queries in one call rather than one query at a time —
        documents rarely use the same words a question does. Not every message needs
        a search: a greeting or a question about the conversation itself does not.

        Passages come back best-match-first, never in the order they run in the
        document: a search returning chunks 8, 3 and 11 is telling you which passages
        matched, not how they follow one another. So when the answer is a sequence —
        steps, phases, an ordered argument — read the document rather than reading the
        results in the order they arrived.

        When a result is clearly the right passage but stops short of answering, read
        around it with read_document. Every result tells you the id of its document,
        which chunk it was, and how many chunks that document has — so a result that
        is chunk 12 of 47 is read further with read_document(document: <that id>,
        from: 10, to: 14). Only ever read an id you were given; a document you were
        not shown cannot be read, and guessing at ids finds nothing.

        To answer what this archive holds rather than what it says, walk it:
        list_collections names the collections this conversation draws on, how many
        documents each holds and which sources feed them; list_documents takes one of
        those slugs and names the documents in it, with the id read_document takes. A
        question like "what is in the handbook?" is both calls and then an answer, all
        in this turn — never stop after a tool result, and never leave your next step
        as a thought. Say what a listing showed in your own words: there are no
        passages in one, so cite nothing from it.

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
