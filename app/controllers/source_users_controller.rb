# Who may manage one source. The counterpart to CollectionUsersController, and
# gated the same way: on administering *this* source, not on being a system
# admin, so whoever set a source up can delegate it.
class SourceUsersController < ApplicationController
  require_role :operator

  before_action :set_source

  def index
    render Views::Sources::People::Index.new(
      source: @source,
      grants: @source.source_users.includes(:user).joins(:user).order("users.email_address"),
      candidates: candidates
    )
  end

  def create
    grant = @source.source_users.new(user_id: params[:user_id], role: params[:role])

    if grant.save
      redirect_to source_people_path(@source), notice: "#{grant.user.email_address} can now manage #{@source.name}."
    else
      redirect_to source_people_path(@source), alert: grant.errors.full_messages.to_sentence
    end
  end

  def update
    grant = @source.source_users.find(params[:id])

    if grant.update(role: params[:role])
      redirect_to source_people_path(@source), notice: "Updated #{grant.user.email_address}."
    else
      redirect_to source_people_path(@source), alert: grant.errors.full_messages.to_sentence
    end
  end

  # Same as collections: revoking your own access is allowed, since a system
  # admin reaches every source without a grant — but the redirect has to land
  # somewhere you can still reach.
  def destroy
    grant = @source.source_users.find(params[:id])
    revoking_own_access = grant.user == Current.user && !Current.user.admin?
    grant.destroy

    if revoking_own_access
      redirect_to sources_path, notice: "You no longer manage #{@source.name}."
    else
      redirect_to source_people_path(@source), notice: "#{grant.user.email_address} can no longer manage #{@source.name}."
    end
  end

  private

  def set_source
    @source = Source.administrable_by(Current.user).find(params[:source_id])
  end

  # Only people who could use the grant. A chat-only account can administer no
  # collection, so it has nothing to feed this source into; system admins reach
  # every source already.
  def candidates
    User.where(role: :operator)
      .where.not(id: @source.source_users.select(:user_id))
      .order(:email_address)
  end
end
