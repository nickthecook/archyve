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

  def initialize(title: nil, contained: true)
    @title = title
    @contained = contained
  end

  def view_template
    doctype
    html do
      head do
        title { [@title, "Archyve"].compact.join(" · ") }
        meta(name: "viewport", content: "width=device-width,initial-scale=1")
        link(rel: "icon", href: "/icon.svg", type: "image/svg+xml")
        csrf_meta_tags
        csp_meta_tag
        stylesheet_link_tag("fonts", "data-turbo-track": "reload")
        stylesheet_link_tag("tailwind", "data-turbo-track": "reload")
        stylesheet_link_tag("landing", "data-turbo-track": "reload")
        javascript_importmap_tags
      end
      body(class: "min-h-screen bg-base text-fg font-sans antialiased") do
        @contained ? contained { yield } : yield
      end
    end
  end

  private

  def contained
    render Views::Chrome.new
    main(class: "mx-auto max-w-3xl px-5 py-10") do
      flash.each do |type, message|
        color = type.to_sym == :alert ? "bg-red-500/10 text-red-300 border-red-500/30" : "bg-accent/10 text-accent border-accent/30"
        div(class: "mb-6 rounded border px-4 py-3 text-sm #{color}") { message }
      end
      yield
    end
  end
end
