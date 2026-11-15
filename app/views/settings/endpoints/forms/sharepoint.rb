# frozen_string_literal: true

class Views::Settings::Endpoints::Forms::Sharepoint < Views::Settings::Endpoints::Form
  private

  def address_hint = "The site's address, ending at its name — nothing after /sites/<name>."
  def address_placeholder = "https://example.sharepoint.com/sites/Team"

  def credential_fields
    field("Client ID", "The app registration's Application (client) ID, from Entra ID → App registrations.") do
      text_input(:client_id, @endpoint.client_id, placeholder: "00000000-0000-0000-0000-000000000000", mono: true)
    end

    field("Client secret", secret_hint) do
      secret_input(:client_secret, stored: @endpoint.client_secret.present?)
    end

    field("Directory ID", "Optional. The tenant's Directory (tenant) ID, if signing in by the site's domain fails.") do
      text_input(:tenant_id, @endpoint.tenant_id, placeholder: "00000000-0000-0000-0000-000000000000", mono: true)
    end
  end

  def secret_hint
    hint = "The secret's Value, not its Secret ID. Stored encrypted."
    return "#{hint} Leave blank to keep the current secret." if @endpoint.persisted?

    hint
  end
end
