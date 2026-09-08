class UnsortedController < ApplicationController
  require_role :operator

  # Unfiled documents from sources this person manages. Before source grants
  # existed this listed every unfiled document to every operator, because a
  # folder source had no owner to scope it by.
  def index
    render Views::Unsorted::Index.new(
      documents: Document.unsorted.reachable_by(Current.user).order(:title),
      # Only offer somewhere you could actually file them.
      collections: Collection.manageable_by(Current.user).order(:name)
    )
  end

  # Assign the selected unsorted documents to a collection (manual membership).
  # Once added they're no longer unsorted, so they drop off this list.
  # Filing needs operator on the destination, not merely the global role — the
  # same rule as uploading into a collection.
  def assign
    collection = Collection.manageable_by(Current.user).find_by!(slug: params[:collection_slug])
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
