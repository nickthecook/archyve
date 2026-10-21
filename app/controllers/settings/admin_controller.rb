module Settings
  # The way into the generated record pages. Each model's own controller gates
  # itself; this one only lists them.
  class AdminController < ApplicationController
    require_role :admin

    def index
      render Views::Settings::Admin::Index.new(
        api_call_count: ApiCall.count,
        api_key_count: ApiKey.count,
        recording: ApiCall.recording_any?
      )
    end
  end
end
