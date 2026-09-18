# frozen_string_literal: true

class Views::Settings::Endpoints::Forms::Bookstack < Views::Settings::Endpoints::Form
  private

  def address_hint = "The wiki's root, without /api."
  def address_placeholder = "https://wiki.example.com"

  def credential_fields
    field("Token ID", "From Edit Profile → API Tokens in BookStack. Not a secret — stored in the clear.") do
      text_input(:token_id, @endpoint.token_id, placeholder: "B7pQ2xN4kLmR8vT1", mono: true)
    end

    field("Token secret", secret_hint) do
      secret_input(:token_secret, stored: @endpoint.token_secret.present?)
    end
  end

  def secret_hint
    return "Shown once, when the token is created. Stored encrypted. Leave blank to keep the current secret." if @endpoint.persisted?

    "Shown once, when the token is created. Stored encrypted."
  end
end
