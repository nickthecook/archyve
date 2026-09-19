class SsoSessionsController < ApplicationController
  allow_unauthenticated_access
  before_action :require_sso_configured

  # POST, not GET: the request phase carries no code yet, but starting it from a
  # link is how OmniAuth earned CVE-2015-9284. Forgery protection applies here
  # exactly as it does to the password form.
  def create
    verifier = Sso::Client.code_verifier
    session[:sso_state] = SecureRandom.urlsafe_base64(32)
    session[:sso_nonce] = SecureRandom.urlsafe_base64(32)
    session[:sso_code_verifier] = verifier

    redirect_to client.authorization_url(
      redirect_uri: sso_callback_url,
      state: session[:sso_state],
      nonce: session[:sso_nonce],
      code_challenge: Sso::Client.code_challenge(verifier)
    ), allow_other_host: true
  rescue Sso::Error => e
    refuse(e.message)
  end

  def callback
    return refuse("Sign-in was cancelled.") if params[:error].present?
    return refuse("That sign-in didn't match this browser. Try again.") unless state_matches?

    claims, id_token = client.exchange(
      code: params[:code].to_s,
      redirect_uri: sso_callback_url,
      code_verifier: session[:sso_code_verifier].to_s,
      nonce: session[:sso_nonce].to_s
    )

    user = Sso::Identity.new(claims).user
    clear_flow_state
    start_new_session_for(user, sso_id_token: id_token)
    redirect_to after_authentication_url
  rescue Sso::Error => e
    refuse(e.message)
  end

  private

  def client = @client ||= Sso::Client.new

  # Hiding the button isn't access control, so the route refuses on its own.
  def require_sso_configured
    redirect_to new_session_path unless Sso.configured?
  end

  def state_matches?
    expected = session[:sso_state]
    expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, params[:state].to_s)
  end

  def clear_flow_state
    session.delete(:sso_state)
    session.delete(:sso_nonce)
    session.delete(:sso_code_verifier)
  end

  def refuse(message)
    clear_flow_state
    redirect_to new_session_path, alert: message
  end
end
