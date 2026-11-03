# frozen_string_literal: true

# The application HTML shell, in Phlex. Page views wrap their content in this via
# Views::Base#around_template. Two modes: `contained` pages get the slim top bar
# and a centred column; full-bleed pages (the landing) manage their own layout.
class Views::Layout < Phlex::HTML
  include Phlex::Rails::Helpers::CSRFMetaTags
  include Phlex::Rails::Helpers::CSPMetaTag
  include Phlex::Rails::Helpers::StyleSheetLinkTag
  include Phlex::Rails::Helpers::JavaScriptImportmapTags
  include Phlex::Rails::Helpers::Flash
  include Phlex::Rails::Helpers::FormAuthenticityToken
  include Phlex::Rails::Helpers::Routes

  # No built-in adapter for cookies; register one so `cookies` works without the
  # deprecated `helpers` proxy. (Layout is a plain Phlex::HTML, not Components::Base.)
  register_value_helper :cookies

  def initialize(title: nil, contained: true, wide: false)
    @title = title
    @contained = contained
    @wide = wide
  end

  def view_template
    doctype
    html(**html_attrs) do
      head do
        title { [@title, Brand.current.name.presence].compact.join(" · ") }
        meta(name: "viewport", content: "width=device-width,initial-scale=1")
        favicon
        csrf_meta_tags
        csp_meta_tag
        stylesheet_link_tag("fonts", "data-turbo-track": "reload")
        stylesheet_link_tag("tailwind", "data-turbo-track": "reload")
        stylesheet_link_tag("landing", "data-turbo-track": "reload")
        stylesheet_link_tag("answer", "data-turbo-track": "reload")
        stylesheet_link_tag("help", "data-turbo-track": "reload")
        javascript_importmap_tags
      end
      body(class: "min-h-screen bg-base text-fg font-sans antialiased") do
        @contained ? contained { yield } : yield
      end
    end
  end

  private

  def favicon
    logo = Brand.current.logo
    if logo
      link(rel: "icon", href: rails_representation_path(logo.variant(:icon), only_path: true), type: "image/png")
    else
      link(rel: "icon", href: "/icon.svg", type: "image/svg+xml")
    end
  end

  # Honour the reduce-motion preference before first paint (no flash): the class
  # lets CSS suppress load animations and signals the JS animation controllers.
  def html_attrs
    cookies[:reduce_motion] == "1" ? { class: "reduce-motion" } : {}
  end

  def contained
    render Views::Chrome.new(wide: @wide)
    main(class: "mx-auto #{@wide ? 'max-w-6xl' : 'max-w-3xl'} px-5 py-6 sm:py-10") do
      flash.to_hash.slice("notice", "alert").each do |type, message|
        color = type.to_sym == :alert ? "bg-red-500/10 text-red-300 border-red-500/30" : "bg-accent/10 text-accent border-accent/30"
        div(class: "mb-6 flex items-center justify-between gap-3 rounded border px-4 py-3 text-sm #{color}") do
          span { message }
          undo(flash[:undo]) if type == "notice" && flash[:undo]
        end
      end
      yield
    end
  end

  # Set by a controller as flash[:undo] = { path:, params: } — a POST that reverses what the notice reports.
  def undo(action)
    form(action: action["path"], method: "post", class: "shrink-0") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      action["params"].each { |name, value| input(type: "hidden", name:, value:) }
      button(type: "submit", class: "font-medium underline underline-offset-2 hover:no-underline") { "Undo" }
    end
  end
end
