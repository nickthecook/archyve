# frozen_string_literal: true

# Abstract base for full-page views. Wraps every page's template in the Phlex
# layout, so a view only defines its content (and optionally #page_title).
# Fragment components (badges, panels, broadcast targets) inherit from
# Components::Base instead, so they render bare.
class Views::Base < Components::Base
  def cache_store = Rails.cache

  private

  def around_template
    render Views::Layout.new(title: page_title) do
      super
    end
  end

  def page_title = nil
end
