class CollectionsController < ApplicationController
  require_role :curator

  # One row per collection for the index. `documents_count` and `status_counts`
  # cover only *active* memberships (the derived "current contents"); a removed
  # membership is a tombstone and doesn't count. See [[collection-membership-policy]].
  Row = Data.define(:collection, :documents_count, :status_counts, :last_activity_at)
  # Whether the user may delete the document outright is resolved once per page
  # rather than per row.
  DocumentRow = Data.define(:document, :purgeable)
  SourceRow = Data.define(:source, :documents_count, :failed_count, :latest_sync)

  # Only collections they can edit. An accessor grant is for chat; it puts
  # nothing in front of a curator here.
  def index
    collections = Collection.manageable_by(Current.user).order(:name).to_a
    @rows = build_rows(collections)
    @unsorted_count = unsorted_count
    render Views::Collections::Index.new(
      rows: @rows,
      unsorted_count: @unsorted_count,
      sources_count: Source.count
    )
  end

  def show
    collection = Collection.manageable_by(Current.user).find_by!(slug: params[:slug])
    sources = collection.sources.order(:name).to_a

    render Views::Collections::Show.new(
      collection:,
      document_rows: manual_document_rows(collection),
      status_counts: collection.collection_memberships.active.joins(:document).group("documents.status").count,
      candidates: addable_documents(collection),
      source_rows: source_rows(sources),
      manageable_source_ids: manageable_source_ids(collection),
      attachable_sources: attachable_sources(collection)
    )
  end

  def create
    collection = Collection.new(collection_params)
    if collection.save
      collection.grant_manager_to!(Current.user)
      redirect_to collections_path, notice: "Created “#{collection.name}”."
    else
      redirect_to collections_path, alert: collection.errors.full_messages.to_sentence
    end
  end

  # The description, and nothing else: a collection's name is its slug's origin
  # and renaming one would leave every c[] link and conversation scope pointing
  # at a collection that no longer answers to that name.
  #
  def update
    collection = Collection.administrable_by(Current.user).find_by!(slug: params[:slug])
    collection.update!(collection_params.slice(:description))
    redirect_to collection_path(collection), notice: "Updated the description."
  end

  # Deleting a collection unfiles its documents; it never destroys them. They
  # belong to the source that produced them, so what goes is the shelf, not the
  # books — anything that was only here becomes Unsorted. Gated on administering
  # *this* collection, so a curator can delete their own without a system
  # admin, and can't touch anybody else's.
  def destroy
    collection = Collection.administrable_by(Current.user).find_by!(slug: params[:slug])
    collection.destroy
    redirect_to collections_path, notice: "Deleted “#{collection.name}”. Its documents are still in the archive."
  end

  private

  # Fed documents are reached through their source; only what was filed by hand
  # is listed on the collection itself.
  def manual_document_rows(collection)
    memberships = collection.collection_memberships.active.manual.includes(document: :source).to_a
    purgeable = purgeable_document_ids(memberships.map(&:document))
    memberships
      .sort_by { |membership| membership.document.title.to_s.downcase }
      .map do |membership|
        DocumentRow.new(document: membership.document, purgeable: purgeable.include?(membership.document_id))
      end
  end

  def source_rows(sources)
    ids = sources.map(&:id)
    counts = Document.where(source_id: ids).where.not(status: "removed").group(:source_id, :status).count
    latest_syncs = SourceSync.where(source_id: ids).select("DISTINCT ON (source_id) *").order(:source_id, started_at: :desc).index_by(&:source_id)

    sources.map do |source|
      by_status = counts.select { |(source_id, _status), _n| source_id == source.id }
      SourceRow.new(
        source:,
        documents_count: by_status.values.sum,
        failed_count: by_status.fetch([source.id, "failed"], 0),
        latest_sync: latest_syncs[source.id]
      )
    end
  end

  # Which of these the user may delete from the archive. Deliberately not gated
  # on this collection: a purge is work on the source that produced the document,
  # which is the rule DocumentsController#destroy enforces — a grant here would
  # let someone delete a document out of every *other* collection too.
  def purgeable_document_ids(documents)
    candidates = documents.select(&:purgeable?)
    manageable = Source.manageable_by(Current.user).where(id: candidates.map(&:source_id)).ids.to_set
    candidates.select { |document| manageable.include?(document.source_id) }.map(&:id).to_set
  end

  # Documents the user could add: everything in the archive not already actively
  # in this collection, and not tombstoned (a removed doc is gone from its source).
  def addable_documents(collection)
    already_in = collection.collection_memberships.active.select(:document_id)
    Document.where.not(status: "removed").where.not(id: already_in).order(:title)
  end

  # Which of this collection's sources the user may open. Independent of access
  # to the collection itself — SourcesController gates on Source.manageable_by,
  # not on any grant here — so the fed list can't link to a page that would
  # then refuse. See CollectionSourcesController#create.
  def manageable_source_ids(collection)
    Source.manageable_by(Current.user).where(id: collection.sources.select(:id)).ids.to_set
  end

  # Sources this person may feed into the collection, minus the ones already
  # doing so. Any grant on the source qualifies — attaching is not configuring.
  def attachable_sources(collection)
    Source.attachable_by(Current.user)
      .where.not(id: collection.sources.select(:id))
      .order(:name)
  end

  def collection_params
    params.require(:collection).permit(:name, :description)
  end

  # Assemble every row from a fixed set of aggregate queries (no per-collection
  # N+1): status breakdown and last activity.
  def build_rows(collections)
    status_by_collection = CollectionMembership.active
      .joins(:document)
      .group(:collection_id, "documents.status")
      .count # => { [collection_id, status] => n }
    last_activity = CollectionMembership.active.group(:collection_id).maximum(:created_at)

    collections.map do |collection|
      status_counts = status_by_collection
        .select { |(collection_id, _status), _n| collection_id == collection.id }
        .transform_keys { |(_collection_id, status)| status }
      Row.new(
        collection:,
        documents_count: status_counts.values.sum,
        status_counts:,
        last_activity_at: last_activity[collection.id] || collection.updated_at
      )
    end
  end

  # "Unsorted" = live documents in no collection. A derived view, not a real
  # collection (see Document.unsorted).
  def unsorted_count
    Document.unsorted.count
  end
end
