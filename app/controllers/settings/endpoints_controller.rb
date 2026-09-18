module Settings
  # The servers sources pull from. Admin-only like the rest of Settings: an
  # operator curates collections, an admin holds the credentials that reach a
  # remote system.
  class EndpointsController < ApplicationController
    require_role :admin

    before_action :set_endpoint, only: [:show, :edit, :update, :destroy, :access]

    def index
      render Views::Settings::Endpoints::Index.new(endpoints: Endpoint.order(:name).includes(:sources))
    end

    def show
      render Views::Settings::Endpoints::Show.new(endpoint: @endpoint)
    end

    def new
      return render Views::Settings::Endpoints::ChooseType.new(types: Endpoint.types) if params[:type].blank?

      render Views::Settings::Endpoints::New.new(endpoint: build_endpoint)
    end

    def create
      endpoint = build_endpoint
      endpoint.assign_attributes(endpoint_params(endpoint))

      if endpoint.save
        redirect_to settings_endpoint_path(endpoint), notice: "Added “#{endpoint.name}”."
      else
        render Views::Settings::Endpoints::New.new(endpoint:), status: :unprocessable_entity
      end
    end

    def edit
      render Views::Settings::Endpoints::Edit.new(endpoint: @endpoint)
    end

    def update
      if @endpoint.update(endpoint_params(@endpoint))
        redirect_to settings_endpoint_path(@endpoint), notice: "Saved."
      else
        render Views::Settings::Endpoints::Edit.new(endpoint: @endpoint), status: :unprocessable_entity
      end
    end

    # restrict_with_error refuses while sources still point here. The page
    # already disables the button in that case; this is the same answer for
    # anything that gets past it.
    def destroy
      if @endpoint.destroy
        redirect_to settings_endpoints_path, notice: "Removed “#{@endpoint.name}”."
      else
        redirect_to settings_endpoint_path(@endpoint), alert: @endpoint.errors.full_messages.to_sentence
      end
    end

    def access
      if @endpoint.access
        redirect_to settings_endpoint_path(@endpoint), notice: "#{@endpoint.name} answered."
      else
        redirect_to settings_endpoint_path(@endpoint), alert: "Couldn't use #{@endpoint.name}."
      end
    end

    private

    def set_endpoint
      @endpoint = Endpoint.find(params[:id])
    end

    # The type comes from the URL, so only registered types are allowed —
    # `constantize` on user input would instantiate any class in the app.
    def build_endpoint
      type = params[:type].to_s
      raise ActionController::BadRequest, "unknown endpoint type" unless Endpoint::TYPES.include?(type)

      type.constantize.new
    end

    def endpoint_params(endpoint)
      params.require(:endpoint).permit(*endpoint.class.permitted_keys)
    end
  end
end
