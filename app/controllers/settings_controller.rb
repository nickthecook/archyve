class SettingsController < ApplicationController
  require_role :admin

  def index
    render Views::Settings::Index.new(
      people_count: User.count,
      server_count: InferenceServer.count,
      model_count: InferenceModel.count,
      endpoint_count: Endpoint.count,
      purpose: Setting.chat_instance_purpose
    )
  end
end
