# frozen_string_literal: true

module Retrieval
  # What one conversation may draw on: everything this person can read,
  # narrowed to what they asked to search.
  #
  # The two filters were inline in Search, which was fine while searching was
  # the only thing a model could do. It isn't any more — a model may now name a
  # document id, and the id it names has to be resolved against exactly the
  # corpus a search would have drawn from, or the two tools disagree about what
  # the conversation can see. Same object, not same idea.
  #
  # Nothing here takes anything a model said. `user` and `scope` are bound by
  # the caller, and an id the model supplies only ever reaches this as an
  # argument to `documents.find_by` — a filter it cannot widen.
  class Corpus
    def self.for(conversation)
      new(user: conversation.user, scope: conversation.retrieval_scope)
    end

    def initialize(user:, scope: nil)
      @user = user
      @scope = scope
    end

    # What the system prompt and the tool descriptions call this corpus.
    def label = @scope&.label || "your whole archive"

    # Document filters as subqueries, for the vector search to AND together.
    # Empty means unrestricted — an admin with no scope — and Search leans on
    # that to skip the join to documents entirely.
    def filters = [retrievable_document_ids, @scope&.document_ids].compact

    # The same corpus as a relation, for resolving a document the model named.
    # A document outside it doesn't resolve, which is the whole of the access
    # control for reading.
    def documents
      relation = Document.retrievable_by(@user)
      @scope ? relation.where(id: @scope.document_ids) : relation
    end

    # The collections this conversation draws on, as a relation. In scope only,
    # deliberately: a listing that named collections this chat cannot search
    # would have the model describing documents it cannot draw on, which is the
    # "I could not find it" versus "that is outside this chat" confusion
    # Chat::Instructions exists to prevent.
    def collections
      relation = Collection.readable_by(@user)
      @scope ? relation.where(id: @scope.collections.map(&:id)) : relation
    end

    private

    # Deliberately retrievable_by, not reachable_by: reading has to match
    # searching. A document in no collection is in nobody's corpus, even though
    # an operator can open it from /unsorted to file it.
    def retrievable_document_ids
      return nil if @user.admin?

      Document.retrievable_by(@user).select(:id)
    end
  end
end
