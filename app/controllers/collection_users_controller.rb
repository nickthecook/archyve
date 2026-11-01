# Who may use one collection. Reached from the collection page as "People".
#
# Gated on administering *this* collection rather than on the global admin
# role: a curator who owns a collection decides who sees it. The lookup goes
# through Collection.administrable_by so the grant is a condition of finding the
# collection at all, not a check that could be forgotten in one action.
class CollectionUsersController < ApplicationController
  require_role :curator

  before_action :set_collection

  def index
    render Views::Collections::People::Index.new(
      collection: @collection,
      grants: @collection.collection_users.includes(:user).joins(:user).order("users.email_address"),
      candidates: candidates
    )
  end

  def create
    grant = @collection.collection_users.new(user_id: params[:user_id], access: params[:access])

    if grant.save
      redirect_to collection_people_path(@collection), notice: "#{grant.user.email_address} can now use #{@collection.name}."
    else
      redirect_to collection_people_path(@collection), alert: grant.errors.full_messages.to_sentence
    end
  end

  def update
    grant = @collection.collection_users.find(params[:id])

    if grant.update(access: params[:access])
      redirect_to collection_people_path(@collection), notice: "Updated #{grant.user.email_address}."
    else
      redirect_to collection_people_path(@collection), alert: grant.errors.full_messages.to_sentence
    end
  end

  # No last-admin guard here, unlike User: a collection left with no
  # administrator is recoverable, because a system admin reaches every
  # collection without a grant. Revoking your *own* access is therefore allowed
  # — but it has to land somewhere you can still reach, or the redirect looks
  # this page up again through administrable_by and 404s on the way out.
  def destroy
    grant = @collection.collection_users.find(params[:id])
    revoking_own_access = grant.user == Current.user && !Current.user.admin?
    grant.destroy

    if revoking_own_access
      redirect_to collections_path, notice: "You no longer have access to #{@collection.name}."
    else
      redirect_to collection_people_path(@collection),
        notice: "#{grant.user.email_address} can no longer use #{@collection.name}."
    end
  end

  private

  def set_collection
    @collection = Collection.administrable_by(Current.user).find_by!(slug: params[:collection_slug])
  end

  # People who don't already have a grant here. Plain users are offerable — that
  # is the point of a grant on a collection they chat against — but system
  # admins are not: they reach every collection without one, so granting them
  # anything is a no-op, and it was the no-op that sorted first in the list.
  def candidates
    User.where.not(role: :admin)
      .where.not(id: @collection.collection_users.select(:user_id))
      .order(:email_address)
  end
end
