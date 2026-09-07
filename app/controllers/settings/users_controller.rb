module Settings
  # Administration of everyone else's accounts. A user administers their own at
  # /account, which needs no role — see AccountsController.
  class UsersController < ApplicationController
    require_role :admin

    before_action :set_user, only: [:edit, :update, :destroy]

    def index
      render Views::Settings::Users::Index.new(users: User.order(:email_address))
    end

    def new
      render Views::Settings::Users::New.new(user: User.new)
    end

    def create
      user = User.new(user_params)

      if user.save
        redirect_to settings_users_path, notice: "Added #{user.email_address}."
      else
        render Views::Settings::Users::New.new(user:), status: :unprocessable_entity
      end
    end

    def edit
      render Views::Settings::Users::Edit.new(user: @user)
    end

    def update
      if @user.update(update_params)
        redirect_to settings_users_path, notice: "Saved #{@user.email_address}."
      else
        render Views::Settings::Users::Edit.new(user: @user), status: :unprocessable_entity
      end
    end

    # The last-admin guard is a before_destroy on the model, so this reports
    # rather than decides — no controller can route around it.
    def destroy
      if @user.destroy
        redirect_to settings_users_path, notice: "Removed #{@user.email_address}."
      else
        redirect_to settings_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email_address, :password, :role)
    end

    # Blank password means "leave it alone", so changing someone's role doesn't
    # require resetting their password at the same time.
    def update_params
      user_params.compact_blank
    end
  end
end
