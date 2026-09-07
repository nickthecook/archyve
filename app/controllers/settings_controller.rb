class SettingsController < ApplicationController
  require_role :admin

  def index
    render Views::Settings::Index.new
  end
end
