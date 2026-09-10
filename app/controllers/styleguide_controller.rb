# The living style guide. Admin-only: it renders real components, so it is a
# maker's tool rather than a feature, but it ships in every environment so the
# deployed app can be checked against its own rules.
class StyleguideController < ApplicationController
  require_role :admin

  def index
    render Views::Styleguide::Index.new
  end
end
