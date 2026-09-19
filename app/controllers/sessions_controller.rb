class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in a few minutes." }

  def new
    render Views::Sessions::New.new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    # Read before terminate_session destroys the row: an SSO session's sign-out
    # has to end the Keycloak session too, or clicking "Sign in with SSO" would
    # silently put them straight back in.
    logout_url = keycloak_logout_url
    terminate_session

    if logout_url
      redirect_to logout_url, status: :see_other, allow_other_host: true
    else
      redirect_to new_session_path, status: :see_other
    end
  end

  private

  def keycloak_logout_url
    return unless Current.session&.sso?
    return unless Sso.configured? && Sso.end_session_endpoint

    query = {
      id_token_hint: Current.session.sso_id_token,
      post_logout_redirect_uri: new_session_url,
      client_id: Sso.client_id
    }
    "#{Sso.end_session_endpoint}?#{query.to_query}"
  rescue ActiveRecord::Encryption::Errors::Base, Sso::Error => e
    # Being unable to sign out is a bad way to discover a key or network
    # problem, so fall back to ending the local session only.
    Rails.logger.warn("SSO logout unavailable: #{e.message}")
    nil
  end
end
