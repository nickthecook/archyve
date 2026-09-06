class CollectionMembershipsController < ApplicationController
  # Add one or more documents to a collection (the user path). Idempotent per
  # CollectionMembership.add: a document already actively in the collection is
  # left as-is (never downgraded), so re-adding is safe.
  def create
    collection = Collection.find_by!(slug: params[:collection_slug])
    documents = Document.where(id: Array(params[:document_ids]).reject(&:blank?))

    documents.each { |document| CollectionMembership.add(document:, collection:) }
    redirect_to collection_path(collection), notice: added_notice(documents.size, collection)
  end

  # Remove a document from a collection (the user path). Only manual memberships
  # are user-editable; a connector row is retracted at the connector, so
  # CollectionMembership.remove raises rather than let one be removed here.
  def destroy
    collection = Collection.find_by!(slug: params[:collection_slug])
    document = Document.find(params[:id])

    CollectionMembership.remove(document:, collection:)
    redirect_to collection_path(collection), notice: "Removed “#{document.title}” from #{collection.name}."
  rescue CollectionMembership::NotUserEditableError
    redirect_to collection_path(collection), alert: "That document is fed by a connector — remove it at the source."
  end

  private

  def added_notice(count, collection)
    return "No documents selected." if count.zero?

    "Added #{count} #{'document'.pluralize(count)} to #{collection.name}."
  end
end
