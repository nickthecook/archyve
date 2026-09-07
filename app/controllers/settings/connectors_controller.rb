module Settings
  class ConnectorsController < ApplicationController
    before_action :set_connector, only: [:show, :edit, :update, :destroy, :sync]

    def index
      render Views::Settings::Connectors::Index.new(connectors: Connector.order(:name))
    end

    def show
      render Views::Settings::Connectors::Show.new(
        connector: @connector,
        syncs: @connector.syncs.recent.limit(10)
      )
    end

    # Without a type, offer the choice; with one, show that type's form. Keeps a
    # single "Add connector" entry point however many connector types exist.
    def new
      return render Views::Settings::Connectors::ChooseType.new(types: Connector.creatable_types) if params[:type].blank?

      render Views::Settings::Connectors::New.new(connector: build_connector, collections: all_collections)
    end

    def create
      connector = build_connector
      connector.assign_attributes(connector_params.except(:collection_ids))

      if connector.save
        connector.update_fed_collections(selected_collections)
        redirect_to settings_connector_path(connector), notice: "Created “#{connector.name}”."
      else
        render Views::Settings::Connectors::New.new(connector:, collections: all_collections),
          status: :unprocessable_entity
      end
    end

    def edit
      render Views::Settings::Connectors::Edit.new(connector: @connector, collections: all_collections)
    end

    def update
      if @connector.update(connector_params.except(:collection_ids))
        @connector.update_fed_collections(selected_collections)
        redirect_to settings_connector_path(@connector), notice: "Saved."
      else
        render Views::Settings::Connectors::Edit.new(connector: @connector, collections: all_collections),
          status: :unprocessable_entity
      end
    end

    # Deleting a connector cascades to its documents, chunks and embeddings —
    # they are source-owned, and this is the record of that source.
    def destroy
      @connector.destroy!
      redirect_to settings_connectors_path, notice: "Deleted “#{@connector.name}”."
    end

    def sync
      unless @connector.supports_sync?
        return redirect_to settings_connector_path(@connector), alert: "This connector has nothing to scan."
      end

      Connectors::SyncJob.perform_later(@connector)
      redirect_to settings_connector_path(@connector), notice: "Sync started."
    end

    private

    def set_connector
      @connector = Connector.find(params[:id])
    end

    # The type comes from the URL. Only types a person may actually add are
    # allowed — `constantize` on user input would otherwise instantiate any class
    # in the app, and manual upload isn't something you create by hand.
    def build_connector
      type = params[:type].to_s
      unless Connector.creatable_types.any? { |klass| klass.name == type }
        raise ActionController::BadRequest, "unknown connector type"
      end

      type.constantize.new
    end

    def connector_params
      params.require(:connector).permit(:name, :path, :sync_interval_minutes, collection_ids: [])
    end

    def selected_collections
      Collection.where(id: connector_params.fetch(:collection_ids, []).reject(&:blank?))
    end

    def all_collections
      Collection.order(:name)
    end
  end
end
