class UnsortedController < ApplicationController
  require_role :curator

  # Unfiled documents from sources this person manages. Before source grants
  # existed this listed every unfiled document to every curator, because a
  # folder source had no owner to scope it by.
  def index
    render Views::Unsorted::Index.new(
      documents: Document.unsorted.reachable_by(Current.user).includes(:source).order(:title),
      # Only offer somewhere you could actually file them.
      collections: Collection.manageable_by(Current.user).order(:name)
    )
  end

  # Assign the selected unsorted documents to a collection (manual membership).
  # Once added they're no longer unsorted, so they drop off this list.
  # Filing needs curator on the destination, not merely the global role — the
  # same rule as uploading into a collection.
  def assign
    collection = Collection.manageable_by(Current.user).find_by!(slug: params[:collection_slug])
    documents = Document.where(id: Array(params[:document_ids]).reject(&:blank?))

    documents.each { |document| CollectionMembership.add(document:, collection:) }
    redirect_to unsorted_path, notice: assigned_notice(documents.size, collection)
  end

  # The other thing to do with a selection: get rid of it. Deleting a hundred
  # stale uploads one at a time is the chore this page exists to spare you, so it
  # takes the same selection `assign` does.
  #
  # Scoped to sources this person manages, as a single purge is — which here costs
  # nothing, since an unfiled document is in no collection and `reachable_by` has
  # already reduced to exactly that.
  def purge
    documents = Document.where(source: Source.manageable_by(Current.user))
      .where(id: Array(params[:document_ids]).reject(&:blank?))
    purgeable, fed = documents.partition(&:purgeable?)

    purgeable.each(&:destroy)
    redirect_to unsorted_path, notice: purged_notice(purgeable.size, fed.size)
  end

  private

  def assigned_notice(count, collection)
    return "No documents selected." if count.zero?

    "Added #{count} #{'document'.pluralize(count)} to #{collection.name}."
  end

  # Reports what a source would put straight back rather than refusing the whole
  # submission: a selection mixing the two is what picking "all" here produces,
  # and the rest of it was a legitimate ask.
  def purged_notice(purged, fed)
    return "No documents selected." if purged.zero? && fed.zero?

    notice = "Deleted #{purged} #{'document'.pluralize(purged)}."
    return notice if fed.zero?

    fed_note = if fed == 1
      "1 is fed by a source — remove it there and sync."
    else
      "#{fed} are fed by a source — remove them there and sync."
    end
    "#{notice} #{fed_note}"
  end
end
