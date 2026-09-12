# frozen_string_literal: true

module Retrieval
  # What a query targets, and a name for it. `nil` — never an instance of this
  # class — means All, the same convention the c[]/doc wire format uses when it
  # omits the parameter entirely.
  #
  # A scope is a *specification*, not a set of ids: it holds collection slugs
  # and document ids, and resolves them against the database on every use. Chat
  # keeps one for the life of a conversation, and re-resolving is exactly what
  # makes that safe — a document filed into the collection on the tenth turn
  # becomes searchable, and a grant revoked on the tenth turn stops working.
  # A frozen id list would do neither.
  #
  # Slugs naming a collection this person can't read are dropped rather than
  # rejected: erroring would confirm the collection exists. A `doc` they can't
  # read is kept as an id but never resolves to a title, and intersects with the
  # readable filter in Search to nothing.
  class Scope
    attr_reader :spec

    # From URL params — the search page.
    def self.from_params(params, user:)
      from_spec({ "c" => Array(params[:c]).reject(&:blank?), "doc" => params[:doc].presence }, user:)
    end

    # From a persisted spec — a conversation, which stores the same shape the
    # URL uses so one encoding covers the search box, the chat, and the link
    # between them.
    def self.from_spec(spec, user:)
      slugs = Array(spec["c"]).reject(&:blank?)
      document_id = spec["doc"].presence

      return nil if slugs.empty? && document_id.nil?

      new(user:, slugs:, document_id:)
    end

    def initialize(user:, slugs: [], document_id: nil)
      @user = user
      @slugs = slugs
      @document_id = document_id
      @spec = { "c" => slugs, "doc" => document_id }.compact_blank
    end

    # What the UI and the system prompt call this scope. A document scope names
    # the document only if they may read it.
    def label
      @label ||= if @document_id
        readable_documents.find_by(id: @document_id)&.title || "one document"
      else
        collections.map(&:name).to_sentence.presence || "these collections"
      end
    end

    # The documents in scope, as a subquery rather than a plucked id list so a
    # large archive stays in SQL. An unreadable slug leaves this empty, which
    # correctly matches nothing.
    def document_ids
      return [@document_id] if @document_id

      CollectionMembership.active.where(collection: collections).select(:document_id)
    end

    # Re-emits the scope as form fields, so a follow-up query stays scoped.
    def hidden_params
      return { "doc" => @document_id } if @document_id

      { "c" => collections.map(&:slug) }
    end

    private

    def collections
      @collections ||= Collection.readable_by(@user).where(slug: @slugs).to_a
    end

    def readable_documents = Document.retrievable_by(@user)
  end
end
