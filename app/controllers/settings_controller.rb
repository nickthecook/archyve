class SettingsController < ApplicationController
  require_role :admin

  def index
    render Views::Settings::Index.new(
      people_count: User.count,
      server_count: InferenceServer.count,
      model_count: InferenceModel.count,
      endpoint_count: Endpoint.count,
      agent_count: Agent.count,
      rounds: rounds,
      record_api_calls: Setting.record_api_calls?,
      record_incoming_api_calls: Setting.record_incoming_api_calls?,
      branded: Setting.where("key LIKE 'brand.%'").exists?,
      feedback_count: Feedback.count
    )
  end

  private

  def rounds = Views::Settings::Number::KEYS.index_with { Setting[it] }
end
