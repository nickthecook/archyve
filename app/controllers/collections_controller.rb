class CollectionsController < ApplicationController
  # One row per collection for the index. `documents_count` and `status_counts`
  # cover only *active* memberships (the derived "current contents"); a removed
  # membership is a tombstone and doesn't count. See [[collection-membership-policy]].
  Row = Data.define(:collection, :documents_count, :status_counts, :connector_fed, :last_activity_at)
  # A document as it sits in one collection: the document plus how it got here
  # (its membership source), which decides whether the user may remove it.
  DocumentRow = Data.define(:document, :source)

  def index
    collections = Collection.order(:name).to_a
    @rows = build_rows(collections)
    @unsorted_count = unsorted_count
    render Views::Collections::Index.new(rows: @rows, unsorted_count: @unsorted_count)
  end

  def show
    collection = Collection.find_by!(slug: params[:slug])
    memberships = collection.collection_memberships.active.includes(:document).to_a
    document_rows = memberships
      .sort_by { |membership| membership.document.title.to_s.downcase }
      .map { |membership| DocumentRow.new(document: membership.document, source: membership.source) }
    status_counts = memberships.each_with_object(Hash.new(0)) { |m, counts| counts[m.document.status] += 1 }

    render Views::Collections::Show.new(
      collection:,
      document_rows:,
      status_counts:,
      connector_fed: collection.connectors.exists?,
      candidates: addable_documents(collection)
    )
  end

  def create
    collection = Collection.new(collection_params)
    if collection.save
      redirect_to collections_path, notice: "Created “#{collection.name}”."
    else
      redirect_to collections_path, alert: collection.errors.full_messages.to_sentence
    end
  end

  private

  # Documents the user could add: everything in the archive not already actively
  # in this collection, and not tombstoned (a removed doc is gone from its source).
  def addable_documents(collection)
    already_in = collection.collection_memberships.active.select(:document_id)
    Document.where.not(status: "removed").where.not(id: already_in).order(:title)
  end

  def collection_params
    params.require(:collection).permit(:name)
  end

  # Assemble every row from a fixed set of aggregate queries (no per-collection
  # N+1): status breakdown, connector-fed set, and last activity.
  def build_rows(collections)
    status_by_collection = CollectionMembership.active
      .joins(:document)
      .group(:collection_id, "documents.status")
      .count # => { [collection_id, status] => n }
    fed = ConnectorCollection.distinct.pluck(:collection_id).to_set
    last_activity = CollectionMembership.active.group(:collection_id).maximum(:created_at)

    collections.map do |collection|
      status_counts = status_by_collection
        .select { |(collection_id, _status), _n| collection_id == collection.id }
        .transform_keys { |(_collection_id, status)| status }
      Row.new(
        collection:,
        documents_count: status_counts.values.sum,
        status_counts:,
        connector_fed: fed.include?(collection.id),
        last_activity_at: last_activity[collection.id] || collection.updated_at
      )
    end
  end

  # "Unsorted" = documents with zero active memberships. A derived view, not a
  # real collection.
  def unsorted_count
    Document.where.not(id: CollectionMembership.active.select(:document_id)).count
  end
end
