# frozen_string_literal: true

module Retrieval
  # Walking the archive rather than searching inside it: which collections a
  # conversation draws on, and what is in one of them.
  #
  # **The corpus is the whole of the access control**, as it is for reading: a
  # collection outside it never appears in a listing and never resolves by
  # slug, and the documents of one that does are counted and paged through
  # `corpus.documents` — so a chat pinned to a single document sees the
  # collections that document is filed in holding one document, which is what
  # this chat can actually draw on.
  class List
    # A listing is read whole, so both pages are a budget rather than a window
    # onto more. Collections take no parameters and so cannot be paged: the cap
    # is generous, and a listing that hit it says how many it left out.
    MAX_COLLECTIONS = 50
    MAX_DOCUMENTS = 25

    def initialize(corpus:)
      @corpus = corpus
    end

    # => Listing
    def collections
      relation = @corpus.collections
      rows = relation.includes(:sources).order(:name).limit(MAX_COLLECTIONS).to_a

      Listing.new(
        kind: :collections, entries: collection_entries(rows),
        to: rows.size, total: relation.count
      )
    end

    # => Listing
    def documents(slug, from: nil, limit: nil)
      collection = @corpus.collections.find_by(slug: slug.to_s)
      return Listing.refused(:not_found, kind: :documents) if collection.nil?

      page(collection, bounded(from, 1), bounded(limit, MAX_DOCUMENTS).clamp(1, MAX_DOCUMENTS))
    end

    private

    def page(collection, from, limit)
      relation = in_scope(collection)
      rows = relation.includes(:source).order(:title, :id).offset(from - 1).limit(limit).to_a

      Listing.new(
        kind: :documents, title: collection.name, entries: document_entries(rows),
        from:, to: from + rows.size - 1, total: relation.count
      )
    end

    def in_scope(collection)
      @corpus.documents.where(id: collection.active_memberships.select(:document_id))
    end

    def collection_entries(collections)
      counts = document_counts(collections)
      collections.map do
        {
          "name" => it.name, "slug" => it.slug,
          "documents" => counts[it.id].to_i, "sources" => it.sources.map(&:name)
        }
      end
    end

    # One grouped count for the whole listing rather than a count per
    # collection, and counted over the corpus rather than over the membership
    # rows, so the number is what this chat could search.
    def document_counts(collections)
      CollectionMembership.active
        .where(collection: collections, document: @corpus.documents)
        .group(:collection_id).count
    end

    def document_entries(documents)
      counts = chunk_counts(documents)
      documents.map do
        {
          "id" => it.id, "title" => it.title, "source" => it.source.name,
          "chunks" => counts[it.id].to_i
        }
      end
    end

    # A document with no chunks hasn't been processed yet, and says so as a
    # zero: the model needs to know read_document has nothing to give it before
    # it spends a round finding out.
    def chunk_counts(documents)
      Chunk.where(document_id: documents.map(&:id)).group(:document_id).count
    end

    # Models send strings, floats and nulls where the schema says integer.
    def bounded(value, default)
      value.nil? ? default : [value.to_i, 1].max
    end
  end
end
