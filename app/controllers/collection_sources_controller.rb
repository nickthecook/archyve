# Which sources feed one collection.
#
# This lives on the collection rather than the source because feeding decides
# what the collection's readers see, and that belongs to whoever owns the
# collection. Attaching needs curator on the collection *and* any grant on the
# source — including the weakest, which means exactly "you may draw on this".
# That split is deliberate: in an organisation, IT owns a source's credentials
# and a team owns what their collection pulls from, and requiring the same
# person to hold both would collapse two different mandates into one.
#
# Detaching needs only the collection side. Removing access can't escalate
# anything, and a collection's owner should always be able to stop pulling.
class CollectionSourcesController < ApplicationController
  require_role :curator

  before_action :set_collection

  def create
    source = Source.attachable_by(Current.user).find(params[:source_id])
    reconcile(source, source.collections | [@collection])
    redirect_to collection_path(@collection), notice: "“#{@collection.name}” now draws on #{source.name}."
  end

  def destroy
    # Not attachable_by: you may always stop drawing on a source, even one you
    # were never granted — otherwise a revoked grant would leave a collection
    # permanently fed by something its owner can't detach.
    source = @collection.sources.find(params[:id])
    reconcile(source, source.collections - [@collection])
    redirect_to collection_path(@collection), notice: "“#{@collection.name}” no longer draws on #{source.name}."
  end

  private

  def set_collection
    @collection = Collection.manageable_by(Current.user).find_by!(slug: params[:collection_slug])
  end

  # Goes through the source's own reconciliation rather than touching the join
  # directly: it files existing documents into a newly fed collection and
  # retracts the memberships it had asserted in a dropped one, neither of which
  # happens on its own.
  #
  # Note the argument is the *source's* full collection list, not this
  # collection's sources — update_fed_collections diffs what it is given and
  # tombstones everything absent from it. Deriving the list from the source is
  # what leaves its other collections, visible to this person or not, alone.
  def reconcile(source, collections)
    source.update_fed_collections(collections)
  end
end
