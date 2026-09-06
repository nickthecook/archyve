class UnsortedController < ApplicationController
  def index
    render Views::Unsorted::Index.new(
      documents: Document.unsorted.order(:title),
      collections: Collection.order(:name)
    )
  end

  # Assign the selected unsorted documents to a collection (manual membership).
  # Once added they're no longer unsorted, so they drop off this list.
  def assign
    collection = Collection.find_by!(slug: params[:collection_slug])
    documents = Document.where(id: Array(params[:document_ids]).reject(&:blank?))

    documents.each { |document| CollectionMembership.add(document:, collection:) }
    redirect_to unsorted_path, notice: assigned_notice(documents.size, collection)
  end

  private

  def assigned_notice(count, collection)
    return "No documents selected." if count.zero?

    "Added #{count} #{'document'.pluralize(count)} to #{collection.name}."
  end
end
