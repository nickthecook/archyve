class SourcesController < ApplicationController
  require_role :operator

  before_action :set_source, only: [:show, :edit, :update, :destroy, :sync]

  def index
    render Views::Sources::Index.new(sources: Source.order(:name))
  end

  def show
    render Views::Sources::Show.new(
      source: @source,
      syncs: @source.syncs.recent.limit(10)
    )
  end

  # Without a type, offer the choice; with one, show that type's form. Keeps a
  # single "Add source" entry point however many source types exist.
  def new
    return render Views::Sources::ChooseType.new(types: Source.creatable_types) if params[:type].blank?

    render Views::Sources::New.new(source: build_source, collections: all_collections)
  end

  def create
    source = build_source
    source.assign_attributes(source_params.except(:collection_ids))

    if source.save
      source.update_fed_collections(selected_collections)
      redirect_to source_path(source), notice: "Created “#{source.name}”."
    else
      render Views::Sources::New.new(source:, collections: all_collections),
        status: :unprocessable_entity
    end
  end

  def edit
    render Views::Sources::Edit.new(source: @source, collections: all_collections)
  end

  def update
    if @source.update(source_params.except(:collection_ids))
      @source.update_fed_collections(selected_collections)
      redirect_to source_path(@source), notice: "Saved."
    else
      render Views::Sources::Edit.new(source: @source, collections: all_collections),
        status: :unprocessable_entity
    end
  end

  # Deleting a source cascades to its documents, chunks and embeddings —
  # they are source-owned, and this is the record of that source.
  def destroy
    @source.destroy!
    redirect_to sources_path, notice: "Deleted “#{@source.name}”."
  end

  def sync
    unless @source.supports_sync?
      return redirect_to source_path(@source), alert: "This source has nothing to scan."
    end

    Sources::SyncJob.perform_later(@source)
    redirect_to source_path(@source), notice: "Sync started."
  end

  private

  def set_source
    @source = Source.find(params[:id])
  end

  # The type comes from the URL. Only types a person may actually add are
  # allowed — `constantize` on user input would otherwise instantiate any class
  # in the app, and manual upload isn't something you create by hand.
  def build_source
    type = params[:type].to_s
    unless Source.creatable_types.any? { |klass| klass.name == type }
      raise ActionController::BadRequest, "unknown source type"
    end

    type.constantize.new
  end

  def source_params
    params.require(:source).permit(:name, :path, :sync_interval_minutes, collection_ids: [])
  end

  def selected_collections
    Collection.where(id: source_params.fetch(:collection_ids, []).reject(&:blank?))
  end

  def all_collections
    Collection.order(:name)
  end
end
