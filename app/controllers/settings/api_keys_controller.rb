module Settings
  class ApiKeysController < ApplicationController
    require_role :admin

    def index
      render Views::Settings::ApiKeys::Index.new(
        page: Page.of(ApiKey.includes(:user), after: params[:after], before: params[:before])
      )
    end

    def show
      render Views::Settings::ApiKeys::Show.new(api_key: ApiKey.find(params[:id]))
    end

    def destroy
      ApiKey.find(params[:id]).destroy
      redirect_to settings_api_keys_path, notice: "API key deleted."
    end
  end
end
