module Settings
  class GroupsController < ApplicationController
    require_role :admin

    before_action :set_group, only: [:show, :update, :destroy]

    def create
      group = Group.new(group_params)

      if group.save
        redirect_to settings_group_path(group), notice: "Added #{group.name}."
      else
        render Views::Settings::Users::Index.new(
          users: User.order(:email_address), groups: Group.includes(:group_users).order(:name), group:
        ), status: :unprocessable_content
      end
    end

    def show
      render_show
    end

    def update
      if @group.update(group_params)
        redirect_to settings_group_path(@group), notice: "Renamed to #{@group.name}."
      else
        render_show(status: :unprocessable_content)
      end
    end

    def destroy
      @group.destroy
      redirect_to settings_users_path, notice: "Removed #{@group.name}. Its members keep any access granted to them directly."
    end

    private

    def set_group
      @group = Group.find(params[:id])
    end

    def render_show(status: :ok)
      render Views::Settings::Groups::Show.new(
        group: @group,
        members: @group.group_users.includes(:user).joins(:user).order("users.email_address"),
        candidates: User.where.not(id: @group.group_users.select(:user_id)).order(:email_address),
        collection_grants: @group.collection_groups.includes(:collection).joins(:collection).order("collections.name"),
        source_grants: @group.source_groups.includes(:source).joins(:source).order("sources.name")
      ), status:
    end

    def group_params
      params.require(:group).permit(:name)
    end
  end
end
