# frozen_string_literal: true

# The application HTML shell, in Phlex instead of ERB. Page views wrap their
# content in this via Views::Base#around_template, so there's one way to write
# views. (Rendering a Phlex component from a controller bypasses Rails' ERB
# layout lookup entirely, so the shell has to live here.)
class Views::Layout < Phlex::HTML
  include Phlex::Rails::Helpers::CSRFMetaTags
  include Phlex::Rails::Helpers::CSPMetaTag
  include Phlex::Rails::Helpers::StyleSheetLinkTag
  include Phlex::Rails::Helpers::JavaScriptImportmapTags
  include Phlex::Rails::Helpers::Flash

  def initialize(title: nil)
    @title = title
  end

  def view_template
    doctype
    html do
      head do
        title { [@title, "Archyve"].compact.join(" · ") }
        meta(name: "viewport", content: "width=device-width,initial-scale=1")
        csrf_meta_tags
        csp_meta_tag
        stylesheet_link_tag("tailwind", "data-turbo-track": "reload")
        javascript_importmap_tags
      end
      body(class: "bg-slate-50 text-slate-900 antialiased") do
        main(class: "container mx-auto max-w-3xl px-5 py-12") do
          render_flash
          yield
        end
      end
    end
  end

  private

  def render_flash
    flash.each do |type, message|
      color = type.to_sym == :alert ? "bg-red-100 text-red-800" : "bg-green-100 text-green-800"
      div(class: "mb-4 rounded-md px-4 py-3 text-sm #{color}") { message }
    end
  end
end
