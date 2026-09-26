# frozen_string_literal: true

module Retrieval
  # What a query targets, and a name for it. `nil` — never an instance of this
  # class — means All, the same convention the c[]/doc wire format uses when it
  # omits the parameter entirely.
  #
  # An *empty* scope is a third thing, and the distinction is the whole reason
  # `from_spec` looks at whether the spec carries a "c" key rather than only at
  # what is in it: a spec with no "c" at all never had a picker in front of it,
  # so it means All, while `"c" => []` came from a picker with everything
  # unticked and means nothing at all. Chat leans on that — a chat scoped to no
  # collections doesn't search, rather than searching everything.
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

    # From URL params — the search page, and the chat page's scope picker. The
    # "c" key is carried through only when the request actually sent one, so an
    # unticked picker (which posts a single blank c[]) stays distinguishable
    # from a URL that never mentioned collections.
    def self.from_params(params, user:)
      spec = { "doc" => params[:doc].presence }.compact
      spec["c"] = Array(params[:c]).reject(&:blank?) if params.key?(:c)

      from_spec(spec, user:)
    end

    # From a persisted spec — a conversation, which stores the same shape the
    # URL uses so one encoding covers the search box, the chat, and the link
    # between them.
    def self.from_spec(spec, user:)
      slugs = Array(spec["c"]).reject(&:blank?)
      document_id = spec["doc"].presence

      return nil if slugs.empty? && document_id.nil? && !spec.key?("c")

      new(user:, slugs:, document_id:)
    end

    def initialize(user:, slugs: [], document_id: nil)
      @user = user
      @slugs = slugs
      @document_id = document_id
      # An empty `c` is kept rather than compacted away, so the spec round-trips
      # back through from_spec as the same scope it came from.
      @spec = { "c" => slugs, "doc" => document_id }.compact
    end

    # Names nothing at all: a picker with everything unticked. Distinct from
    # nil, which is All — this one matches no document on purpose.
    #
    # Not called `empty?`, deliberately: that would make an empty scope `blank?`
    # to Rails, and a scope that vanishes from an `if scope.present?` is exactly
    # the All-instead-of-nothing confusion this class exists to prevent.
    def names_nothing? = @slugs.empty? && @document_id.nil?

    # What the UI and the system prompt call this scope. A document scope names
    # the document only if they may read it.
    def label
      @label ||= if @document_id
        readable_documents.find_by(id: @document_id)&.title || "one document"
      elsif names_nothing?
        "no collections"
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

    # Re-emits the scope as form fields, so a follow-up query stays scoped. A
    # scope that resolves to no collection still emits a blank c[], because a
    # form that emitted nothing would come back as All — widening the search on
    # the way to the next query is the one thing this must not do.
    def hidden_params
      return { "doc" => @document_id } if @document_id

      { "c" => collections.map(&:slug).presence || [""] }
    end

    # The collections this scope draws on. A document scope answers with the
    # readable collections that document is filed in rather than with none: the
    # chat reaches that document *through* them, and a listing that came back
    # empty would read as an archive with nothing in it.
    def collections
      @collections ||= readable_collections.to_a
    end

    private

    def readable_collections
      relation = Collection.readable_by(@user)
      return relation.where(id: collection_ids_of_scoped_document) if @document_id

      relation.where(slug: @slugs)
    end

    def collection_ids_of_scoped_document
      CollectionMembership.active.where(document_id: @document_id).select(:collection_id)
    end

    def readable_documents = Document.retrievable_by(@user)
  end
end
