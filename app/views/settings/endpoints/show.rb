# frozen_string_literal: true

class Views::Settings::Endpoints::Show < Views::Base
  def initialize(endpoint:)
    @endpoint = endpoint
    @sources = endpoint.sources.order(:name)
  end

  def view_template
    a(href: settings_endpoints_path, class: "text-sm text-muted hover:text-fg transition-colors") { "← Endpoints" }

    heading
    access_panel
    sources_section
    remove_section
  end

  private

  def page_title = @endpoint.name

  def heading
    header(class: "mt-3 mb-7 flex flex-wrap items-start justify-between gap-4") do
      div(class: "min-w-0") do
        div(class: "flex items-center gap-2") do
          h1(class: "text-2xl font-semibold tracking-tight") { @endpoint.name }
          span(class: "rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { @endpoint.type_label }
        end
        p(class: "mt-1 truncate font-mono text-sm text-muted") { @endpoint.base_url }
      end
      div(class: "flex shrink-0 items-center gap-2") do
        access_button
        a(href: edit_settings_endpoint_path(@endpoint), class: quiet_button) { "Edit" }
      end
    end
  end

  # Outlined: using the endpoint proves it works, it doesn't commit anything.
  def access_button
    form(action: access_settings_endpoint_path(@endpoint), method: "post", class: "inline") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: outlined_button) { "Test connection" }
    end
  end

  def access_panel
    div(class: "mb-8 rounded-lg border border-line bg-ink/40 px-5 py-4") do
      if @endpoint.accessed_at.blank?
        p(class: "text-sm text-muted") { "Not used yet." }
        p(class: "mt-1 text-xs text-faint") do
          "Test the connection to confirm the credentials work before operators build sources on it."
        end
      elsif @endpoint.accessible?
        p(class: "text-sm text-fg") { "Last used #{time_ago_in_words(@endpoint.accessed_at)} ago." }
      else
        p(class: "text-sm text-red-300") { "Failed #{time_ago_in_words(@endpoint.accessed_at)} ago." }
        p(class: "mt-1 break-words font-mono text-xs text-red-300/70") { @endpoint.access_error.to_s }
      end
    end
  end

  # The list an admin needs before removing anything: who depends on this
  # credential. Sources themselves are an operator's business, so these are
  # named and linked, not managed here.
  def sources_section
    section(class: "mb-8") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Sources using this endpoint" }
      @sources.any? ? source_cards : no_sources
    end
  end

  def source_cards
    div(class: "flex flex-col gap-3") do
      @sources.each do |source|
        a(
          href: source_path(source),
          class: "flex items-center justify-between gap-3 rounded-lg border border-line bg-ink/40 p-4 hover:border-line-2 transition-colors"
        ) do
          span(class: "truncate text-sm font-medium text-fg") { source.name }
          span(class: "shrink-0 text-xs text-muted") { last_sync(source) }
        end
      end
    end
  end

  def last_sync(source)
    return "never synced" if source.last_synced_at.blank?

    "synced #{time_ago_in_words(source.last_synced_at)} ago"
  end

  def no_sources
    div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
      p(class: "text-sm text-muted") { "No sources yet." }
      p(class: "mt-1 text-xs text-faint") { "An operator can now point one at this server." }
    end
  end

  def remove_section
    section do
      h2(class: "mb-3 text-sm font-medium text-muted") { "Remove" }
      div(class: "flex flex-wrap items-center justify-between gap-4 rounded-lg border border-line bg-ink/40 px-5 py-4") do
        p(class: "max-w-prose text-xs text-faint") { remove_hint }
        @sources.any? ? blocked_remove_button : remove_button
      end
    end
  end

  def remove_hint
    return "The credentials go with it. Nothing else is affected." if @sources.empty?

    count = @sources.size
    "#{count} #{'source'.pluralize(count)} #{count == 1 ? 'pulls' : 'pull'} through this endpoint. Remove #{count == 1 ? 'it' : 'them'} first."
  end

  # Disabled rather than hidden: restrict_with_error would refuse anyway, and
  # saying why up front beats a click that lands on a flash message.
  def blocked_remove_button
    span(class: "#{danger_button} opacity-40", aria_disabled: "true") { "Remove endpoint" }
  end

  def remove_button
    form(
      action: settings_endpoint_path(@endpoint),
      method: "post",
      class: "inline",
      data: { turbo_confirm: "Remove “#{@endpoint.name}”?" }
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "delete")
      button(type: "submit", class: danger_button) { "Remove endpoint" }
    end
  end

  def danger_button
    "rounded border border-red-400/40 px-3 py-2 text-sm font-medium text-red-300 hover:bg-red-400/10 transition-colors"
  end

  def outlined_button
    "rounded border border-accent/60 bg-accent/10 px-3 py-2 text-sm text-accent hover:bg-accent/20 " \
      "hover:border-accent transition-colors"
  end

  def quiet_button
    "rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg hover:border-line-2 " \
      "transition-colors"
  end
end
