module Settings
  class UserGrantsController < ApplicationController
    require_role :admin

    GRANTS = { "collection" => :collection_users, "source" => :source_users }.freeze

    before_action :set_user

    def create
      grant = grants.new("#{params[:kind]}_id" => params[:subject_id], access: params[:access])

      if grant.save
        redirect_to edit_settings_user_path(@user),
          notice: "#{@user.email_address} has #{grant.access} access to #{subject_of(grant).name} again."
      else
        redirect_to edit_settings_user_path(@user), alert: grant.errors.full_messages.to_sentence
      end
    end

    def destroy
      grant = grants.find(params[:id])

      if @user.admin?
        return redirect_to edit_settings_user_path(@user),
          alert: "#{@user.email_address} is an admin, so revoking a grant would change nothing. Change their role first."
      end

      grant.destroy

      flash[:undo] = {
        "path" => public_send("settings_user_#{params[:kind]}_grants_path", @user),
        "params" => { "subject_id" => subject_of(grant).id, "access" => grant.access }
      }
      redirect_to edit_settings_user_path(@user),
        notice: "#{@user.email_address} no longer has #{grant.access} access to #{subject_of(grant).name}."
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    def grants = @user.public_send(GRANTS.fetch(params[:kind]))

    def subject_of(grant) = grant.public_send(params[:kind])
  end
end
