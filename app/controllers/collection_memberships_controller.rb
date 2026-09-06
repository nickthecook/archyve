class CollectionMembershipsController < ApplicationController
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
end
