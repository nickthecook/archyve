# frozen_string_literal: true

class Views::Settings::Endpoints::Forms::Bamboohr < Views::Settings::Endpoints::Form
  private

  def address_hint = "Your company's BambooHR address."
  def address_placeholder = "https://example.bamboohr.com"

  def credential_fields
    field("API key", api_key_hint) do
      secret_input(:api_key, stored: @endpoint.api_key.present?)
    end
  end

  def api_key_hint
    hint = "From your name in BambooHR → API Keys. Archyve reads the company files that user can see, so a " \
      "dedicated user is best. Stored encrypted."
    return "#{hint} Leave blank to keep the current key." if @endpoint.persisted?

    hint
  end
end
