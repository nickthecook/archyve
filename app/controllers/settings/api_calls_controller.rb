module Settings
  class ApiCallsController < ApplicationController
    require_role :admin

    LIMIT = 100

    def index
      render Views::Settings::ApiCalls::Index.new(
        api_calls: ApiCall.recent.limit(LIMIT),
        limit: LIMIT,
        recording: ApiCall.recording?
      )
    end

    def show
      render Views::Settings::ApiCalls::Show.new(api_call: ApiCall.find(params[:id]))
    end
  end
end
