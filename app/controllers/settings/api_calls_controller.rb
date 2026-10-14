module Settings
  class ApiCallsController < ApplicationController
    require_role :admin

    LIMIT = 100

    def index
      listing = ApiCalls::Listing.new(params)

      render Views::Settings::ApiCalls::Index.new(
        api_calls: listing.rows(limit: LIMIT),
        limit: LIMIT,
        recording: ApiCall.recording?,
        facets: listing.facets,
        filtered: listing.filtered?
      )
    end

    def show
      render Views::Settings::ApiCalls::Show.new(api_call: ApiCall.find(params[:id]))
    end
  end
end
