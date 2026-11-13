module Settings
  class GroupUsersController < ApplicationController
    require_role :admin

    before_action :set_group

    def create
      member = @group.group_users.new(user_id: params[:user_id])

      if member.save
        redirect_to settings_group_path(@group), notice: "Added #{member.user.email_address} to #{@group.name}."
      else
        redirect_to settings_group_path(@group), alert: member.errors.full_messages.to_sentence
      end
    end

    def destroy
      member = @group.group_users.find(params[:id])
      member.destroy
      redirect_to settings_group_path(@group), notice: "Removed #{member.user.email_address} from #{@group.name}."
    end

    private

    def set_group
      @group = Group.find(params[:group_id])
    end
  end
end
