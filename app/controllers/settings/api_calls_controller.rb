module Settings
  class ApiCallsController < ApplicationController
    require_role :admin

    def index
      listing = ApiCalls::Listing.new(params)

      render Views::Settings::ApiCalls::Index.new(
        page: listing.page,
        recording: ApiCall.recording_any?,
        facets: listing.facets,
        query: listing.query
      )
    end

    def show
      render Views::Settings::ApiCalls::Show.new(api_call: ApiCall.find(params[:id]))
    end
  end
end
