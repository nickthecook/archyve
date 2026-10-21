# Your own account. Open to every signed-in user regardless of role — this is
# how a non-admin changes their own password, so gating it would leave most
# people unable to.
class AccountsController < ApplicationController
  def show
    render Views::Accounts::Show.new(
      user: Current.user, api_keys: Current.user.api_keys.recent, new_token: flash[:api_key_token]
    )
  end

  def update
    user = Current.user

    # Letting an SSO user set a password would be a way around the Keycloak
    # group check: they could then sign in at /session/new after their access
    # was revoked. The view hides the form too; this is the half that enforces.
    if user.sso?
      return redirect_to(account_path, alert: "Your password is managed by your SSO provider.")
    end

    unless user.authenticate(params[:current_password])
      return redirect_to(account_path, alert: "That isn't your current password.")
    end

    if user.update(password_params)
      # A password change should end sessions on other devices — that is the
      # point of changing it. The current one survives so you aren't signed out
      # of the page you just used.
      user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to account_path, notice: "Password changed. Any other signed-in devices were signed out."
    else
      redirect_to account_path, alert: user.errors.full_messages.to_sentence
    end
  end

  private

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
