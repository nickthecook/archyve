class SettingsController < ApplicationController
  require_role :admin

  def index
    render Views::Settings::Index.new(people_count: User.count)
  end
end
