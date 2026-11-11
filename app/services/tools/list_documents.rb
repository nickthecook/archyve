# frozen_string_literal: true

module Tools
  # What is in one collection, by title, so a promising title goes straight to
  # read_document with the id beside it.
  #
  # Paged like a read, and for the same reason: a collection of four hundred
  # documents listed whole is most of a context window spent on titles. `from`
  # and `limit` rather than `from` and `to` — how many rows to see is a
  # different question from which chunks of a document to read, and a listing
  # has no meaningful "up to row 40 of this one".
  #
  # A slug outside this chat's corpus comes back the way read_document's
  # not_found does, and for the same reason: telling "no such collection" apart
  # from "not one of yours" turns a guessed slug into an enumeration oracle.
  #
  # Nothing it returns is citable — see Tools::Base::NOT_CITABLE.
  class ListDocuments < Base
    NAME = "list_documents"
    def name = NAME

    parameters do
      string :collection,
        description: "The slug of the collection to list, exactly as list_collections gave it."
      integer :from,
        description: "First document to list, counting from 1. Defaults to the start.",
        required: false
      integer :limit,
        description: "How many documents to list, at most #{Retrieval::List::MAX_DOCUMENTS}.",
        required: false
    end

    def description
      <<~TEXT.strip
        List the documents in one collection of #{scope_label}, by title.
        Call list_collections first for the slug. Each document comes with the id
        read_document takes and how many chunks it has, so a title that answers the question
        can be read directly instead of searched for. Nothing it returns is a passage, so
        nothing it returns can be cited.
      TEXT
    end

    def execute(collection:, from: nil, limit: nil)
      return budget_spent("listed documents") if over_budget?

      spend_round
      observer&.listing_started
      listing = Retrieval::List.new(corpus:).documents(collection, from:, limit:)
      observer&.listing_finished(listing)

      respond(listing)
    end

    private

    def default_max_rounds = Setting.chat_max_listing_rounds

    def respond(listing)
      return not_found if listing.refused?
      return overshot(listing) if listing.overshot?
      return empty(listing) if listing.empty?

      {
        status: "ok",
        collection: listing.title,
        documents: { from: listing.from, to: listing.to, total: listing.total },
        results: listing.entries,
        instruction: "#{next_step}#{more(listing)} #{NOT_CITABLE}"
      }
    end

    # Deliberately incurious about why. See the note at the top of this class.
    def not_found
      {
        status: "not_found",
        instruction: "No such collection in #{scope_label}. Call list_collections to see which " \
                     "there are, and do not tell the user a collection exists that you could not list."
      }
    end

    def empty(listing)
      {
        status: "no_documents",
        collection: listing.title,
        instruction: "That collection has no documents this conversation can draw on. Say so " \
                     "rather than answering from your own knowledge."
      }
    end

    def overshot(listing)
      {
        status: "out_of_range",
        collection: listing.title,
        documents: { total: listing.total },
        instruction: "That collection holds #{listing.total} #{'document'.pluralize(listing.total)}. " \
                     "Call list_documents again starting inside it."
      }
    end

    # What the model can do with the ids it now has. See the note on
    # Tools::ListCollections#next_step for why a result says this at all.
    def next_step
      "Read one with read_document, using the id beside its title, or search_archive for what " \
        "they say; answer the user in this same turn either way."
    end

    # Said only when it is true — a model told every time that more might remain
    # learns to ignore it.
    def more(listing)
      return "" unless listing.more?

      remaining = listing.total - listing.to
      " #{remaining} more #{'document'.pluralize(remaining)} follow; call list_documents again " \
        "with from: #{listing.to + 1} if you need them."
    end
  end
end
