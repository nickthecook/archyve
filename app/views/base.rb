# frozen_string_literal: true

# Abstract base for full-page views. Wraps every page's template in the Phlex
# layout, so a view only defines its content (and optionally #page_title /
# #contained?). Fragment components (badges, panels, broadcast targets) inherit
# from Components::Base instead, so they render bare.
class Views::Base < Components::Base
  def cache_store = Rails.cache

  private

  # The trail back up, opening any page you came down into. Here rather than on
  # Components::Base because it belongs to a whole page, never to a fragment of
  # one. See Views::Breadcrumb for what a crumb is.
  def breadcrumb(*trail)
    render Views::Breadcrumb.new(*trail)
  end

  def around_template
    render Views::Layout.new(title: page_title, contained: contained?) do
      super
    end
  end

  def page_title = nil
  def contained? = true
end
