# frozen_string_literal: true

class Views::Settings::Endpoints::Forms::Web < Views::Settings::Endpoints::Form
  SCHEMES = {
    "none" => ["Public", "The site is readable without signing in."],
    "basic" => ["HTTP Basic", "A username and password sent on every request."],
    "header" => ["Fixed header", "A bearer token, API key or proxy secret sent on every request."]
  }.freeze

  private

  def address_hint = "The site's address, without a path. Which part of it to crawl is set on the source."
  def address_placeholder = "https://docs.example.com"

  def credential_fields
    field("Sign-in", "Whatever a crawler can carry on every request. Cookie and form logins aren't supported.") do
      scheme_choices
    end

    basic_fields
    header_fields
  end

  # Both credential sets are rendered, and the scheme picker decides which one
  # is meaningful. Hiding the other half would need JavaScript to be legible,
  # and the validations only run against the scheme that was chosen.
  def scheme_choices
    div(class: "flex flex-col gap-1.5 rounded border border-line bg-void/40 p-3") do
      SCHEMES.each { |value, (label_text, hint)| scheme_choice(value, label_text, hint) }
    end
  end

  def scheme_choice(value, label_text, hint)
    label(class: "flex cursor-pointer items-start gap-2.5 text-sm text-muted hover:text-fg transition-colors") do
      input(
        type: "radio",
        name: "endpoint[auth_scheme]",
        value: value,
        checked: @endpoint.scheme == value,
        class: "mt-1 h-3.5 w-3.5 accent-accent"
      )
      span do
        span(class: "block text-fg") { label_text }
        span(class: "block text-xs text-faint") { hint }
      end
    end
  end

  def basic_fields
    field("Username", "For HTTP Basic. Ignored unless Basic is chosen above.") do
      text_input(:username, @endpoint.username, placeholder: "archyve", mono: true)
    end

    field("Password", secret_hint("password")) do
      secret_input(:password, stored: @endpoint.password.present?)
    end
  end

  def header_fields
    field("Header name", "For a fixed header. Authorization unless the site wants something else.") do
      text_input(:header_name, @endpoint.header_name, placeholder: Endpoints::Web::DEFAULT_HEADER_NAME, mono: true)
    end

    field("Header value", secret_hint("value")) do
      secret_input(:header_value, stored: @endpoint.header_value.present?)
    end
  end

  def secret_hint(noun)
    stored = "Stored encrypted. Leave blank to keep the current #{noun}."
    @endpoint.persisted? ? stored : "Stored encrypted."
  end
end
