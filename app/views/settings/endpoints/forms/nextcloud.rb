# frozen_string_literal: true

class Views::Settings::Endpoints::Forms::Nextcloud < Views::Settings::Endpoints::Form
  private

  def address_hint = "The server's root, without /remote.php or /index.php."
  def address_placeholder = "https://cloud.example.com"

  def credential_fields
    field("Username", "The Nextcloud user whose files Archyve reads. Its own files, plus anything shared with it.") do
      text_input(:username, @endpoint.username, placeholder: "archyve", mono: true)
    end

    field("App password", password_hint) do
      secret_input(:app_password, stored: @endpoint.app_password.present?)
    end
  end

  # An app password rather than the account password: it skips two-factor, which
  # an API client cannot answer, and revoking it costs the user nothing else.
  def password_hint
    hint = "Create one under Settings → Security → “Devices & sessions” in Nextcloud. Stored encrypted."
    return "#{hint} Leave blank to keep the current password." if @endpoint.persisted?

    hint
  end
end
