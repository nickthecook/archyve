# Who may use one collection. Reached from the collection page as "People".
class CollectionUsersController < ApplicationController
  require_role :admin

  before_action :set_collection

  def index
    render Views::Collections::People::Index.new(
      collection: @collection,
      grants: @collection.collection_users.includes(:user).joins(:user).order("users.email_address"),
      candidates: candidates,
      group_grants: @collection.collection_groups.includes(group: :group_users).joins(:group).order("groups.name"),
      group_candidates: Group.where.not(id: @collection.collection_groups.select(:group_id)).order(:name)
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

  def destroy
    grant = @collection.collection_users.find(params[:id])
    grant.destroy
    redirect_to collection_people_path(@collection),
      notice: "#{grant.user.email_address} can no longer use #{@collection.name}."
  end

  private

  def set_collection
    @collection = Collection.find_by!(slug: params[:collection_slug])
  end

  # Admins reach every collection without a grant, so granting them anything
  # is a no-op.
  def candidates
    User.where.not(role: :admin)
      .where.not(id: @collection.collection_users.select(:user_id))
      .order(:email_address)
  end
end
