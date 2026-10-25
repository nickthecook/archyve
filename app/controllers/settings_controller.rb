class SettingsController < ApplicationController
  require_role :admin

  def index
    render Views::Settings::Index.new(
      people_count: User.count,
      server_count: InferenceServer.count,
      model_count: InferenceModel.count,
      endpoint_count: Endpoint.count,
      prompt: Setting.chat_instance_purpose,
      rounds: rounds,
      record_api_calls: Setting.record_api_calls?,
      record_incoming_api_calls: Setting.record_incoming_api_calls?,
      branded: Setting.where("key LIKE 'brand.%'").exists?
    )
  end

  private

  # In the order a turn spends them, not the order they were added.
  def rounds
    {
      "chat.max_search_rounds" => Setting.chat_max_search_rounds,
      "chat.max_read_rounds" => Setting.chat_max_read_rounds,
      "chat.max_listing_rounds" => Setting.chat_max_listing_rounds
    }
  end
end
