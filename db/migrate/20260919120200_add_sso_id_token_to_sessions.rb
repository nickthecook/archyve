class AddSsoIdTokenToSessions < ActiveRecord::Migration[8.1]
  def change
    # Does double duty: its presence is what marks a session as SSO-authenticated,
    # and its value is the id_token_hint that makes Keycloak's logout silent
    # rather than showing the user a confirmation page on the way out.
    add_column :sessions, :sso_id_token, :text
  end
end
