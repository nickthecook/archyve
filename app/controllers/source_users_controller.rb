# Who may manage one source. The counterpart to CollectionUsersController.
class SourceUsersController < ApplicationController
  require_role :admin

  before_action :set_source

  def index
    render Views::Sources::People::Index.new(
      source: @source,
      grants: @source.source_users.includes(:user).joins(:user).order("users.email_address"),
      candidates: candidates,
      group_grants: @source.source_groups.includes(group: :group_users).joins(:group).order("groups.name"),
      group_candidates: Group.where.not(id: @source.source_groups.select(:group_id)).order(:name)
    )
  end

  def create
    grant = @source.source_users.new(user_id: params[:user_id], access: params[:access])

    if grant.save
      redirect_to source_people_path(@source), notice: "#{grant.user.email_address} can now manage #{@source.name}."
    else
      redirect_to source_people_path(@source), alert: grant.errors.full_messages.to_sentence
    end
  end

  def update
    grant = @source.source_users.find(params[:id])

    if grant.update(access: params[:access])
      redirect_to source_people_path(@source), notice: "Updated #{grant.user.email_address}."
    else
      redirect_to source_people_path(@source), alert: grant.errors.full_messages.to_sentence
    end
  end

  def destroy
    grant = @source.source_users.find(params[:id])
    grant.destroy
    redirect_to source_people_path(@source), notice: "#{grant.user.email_address} can no longer manage #{@source.name}."
  end

  private

  def set_source
    @source = Source.find(params[:source_id])
  end

  # Only people who could use the grant. A chat-only account can edit no
  # collection, so it has nothing to feed this source into; admins reach every
  # source already.
  def candidates
    User.where(role: :curator)
      .where.not(id: @source.source_users.select(:user_id))
      .order(:email_address)
  end
end
