# frozen_string_literal: true

module Tools
  # What this conversation draws on, collection by collection.
  #
  # Searching answers "what does the archive say about X"; nothing about a
  # search answers "what is in here" or "where did these documents come from".
  # Provenance is half the point — the sources feeding a collection are a fact
  # no amount of searching surfaces.
  #
  # Nothing it returns is citable — see Tools::Base::NOT_CITABLE.
  class ListCollections < Base
    def name = "list_collections"

    def description
      <<~TEXT.strip
        List the collections this conversation draws on — what each is for, how many
        documents are in it, and which sources feed it. Use it to answer what the archive
        covers or where its documents come from, and to get the slug that list_documents
        takes. Nothing it returns is a passage, so nothing it returns can be cited.
      TEXT
    end

    # No parameters at all: the scope is bound, and this lists exactly it.
    # Anything a model sent would be ignored, so it is told there is nothing to
    # send. The keyword splat is there so a model that sends something anyway
    # gets its listing rather than an argument error.
    def execute(**)
      return budget_spent("listed the collections") if over_budget?

      spend_round
      observer&.listing_started
      listing = Retrieval::List.new(corpus:).collections
      observer&.listing_finished(listing)

      respond(listing)
    end

    private

    def respond(listing)
      return nothing if listing.empty?

      {
        status: "ok",
        scope: scope_label,
        collections: listing.entries,
        instruction: "#{next_step}#{truncation_note(listing)} #{NOT_CITABLE}"
      }
    end

    # The result says what the next call is, not only what this one returned.
    # A listing is usually the first half of an errand — "what is in X" is two
    # calls — and a model that works its next step out in the analysis channel
    # can end the turn there, having listed and answered nothing.
    def next_step
      "If the question is about what one of these holds, call list_documents now with that " \
        "collection's slug; answer the user in this same turn either way."
    end

    # A scope that resolves to nothing at all. Chat doesn't offer tools in that
    # case, so this is the archive having no collections in it rather than the
    # user having picked none — and the model is told which.
    def nothing
      {
        status: "no_collections",
        instruction: "There are no collections in #{scope_label} to list. Say so rather than " \
                     "answering from your own knowledge."
      }
    end

    def truncation_note(listing)
      return "" unless listing.more?

      " Showing #{listing.to} of #{listing.total} collections; the rest are not listed."
    end
  end
end
