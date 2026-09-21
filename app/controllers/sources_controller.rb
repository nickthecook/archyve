class SourcesController < ApplicationController
  require_role :operator

  # Every key a source form may submit. Keys backed by `state` are absent and
  # must stay absent — that allowlist is the whole enforcement of the
  # config/state split described in Source. spec/models/source_spec.rb fails if
  # a state key ever appears here.
  # Only `config` keys, never `state` ones: what a person set, never what a
  # source learned. spec/models/source_spec.rb holds that line.
  PERMITTED_PARAMS = [
    :name, :path, :endpoint_id, :sync_interval_minutes, :ocr,
    :path_prefix, :start_path, :content_selector, :max_pages, :max_depth, :crawl_delay_seconds,
    { collection_ids: [], selectors: [] }
  ].freeze

  before_action :set_source, only: [:show, :edit, :update, :destroy, :sync]

  def index
    render Views::Sources::Index.new(sources: Source.manageable_by(Current.user).order(:name))
  end

  def show
    render Views::Sources::Show.new(
      source: @source,
      syncs: @source.syncs.recent.limit(10)
    )
  end

  # Without a type, offer the choice; with one, show that type's form. Keeps a
  # single "Add source" entry point however many source types exist.
  # Also the target of the form's own "Browse" button, which re-GETs this page
  # with a different server chosen. The submitted fields ride along in the query
  # string and are assigned back, so switching servers loses nothing typed so far.
  def new
    return render Views::Sources::ChooseType.new(types: Source.creatable_types) if params[:type].blank?

    source = build_source
    source.assign_attributes(source_params.except(:collection_ids)) if params[:source].present?
    source.endpoint ||= endpoint_options(source).first

    render Views::Sources::New.new(**form_context(source))
  end

  def create
    source = build_source
    source.assign_attributes(source_params.except(:collection_ids))

    if source.save
      source.grant_admin_to!(Current.user)
      source.update_fed_collections(selected_collections) if source.feeds_collections?
      redirect_to source_path(source), notice: "Created “#{source.name}”."
    else
      render Views::Sources::New.new(**form_context(source)), status: :unprocessable_entity
    end
  end

  def edit
    render Views::Sources::Edit.new(**form_context(@source))
  end

  # The endpoint is deliberately not in the permitted list on update: every
  # document this source owns is keyed by an id that only means something on the
  # server that produced it, so repointing would silently re-key the lot.
  def update
    if @source.update(source_params.except(:collection_ids, :endpoint_id))
      @source.update_fed_collections(selected_collections) if @source.feeds_collections?
      redirect_to source_path(@source), notice: "Saved."
    else
      render Views::Sources::Edit.new(**form_context(@source)), status: :unprocessable_entity
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
    @source = Source.manageable_by(Current.user).find(params[:id])
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
    params.require(:source).permit(*PERMITTED_PARAMS)
  end

  # Everything the form needs, including the one part that isn't in our own
  # database: the source's catalogue comes off the far end over HTTP, which is
  # the controller's job and never the view's.
  def form_context(source)
    { source:, collections: all_collections, endpoints: endpoint_options(source), catalogue: source.catalogue }
  end

  # Servers this type can point at. A source whose endpoint_type is nil reads
  # something local and gets no picker.
  def endpoint_options(source)
    type = source.class.endpoint_type
    type ? Endpoint.where(type: type.name).order(:name) : Endpoint.none
  end

  # What this source should feed after the save.
  #
  # Two rules, both load-bearing. Only collections this person manages can be
  # *chosen* — feeding a collection decides what its readers see, so it belongs
  # to the collection, not to whoever happens to own the source. And feeds to
  # collections they can't see are carried over untouched: update_fed_collections
  # diffs the full list and tombstones everything missing from it, so submitting
  # only the visible ones would silently unfile another team's documents.
  def selected_collections
    chosen = manageable_collections.where(id: source_params.fetch(:collection_ids, []).reject(&:blank?))
    invisible = @source ? @source.collections.where.not(id: manageable_collections.select(:id)) : Collection.none

    Collection.where(id: chosen.select(:id)).or(Collection.where(id: invisible.select(:id)))
  end

  # Offered in the feed picker: only collections this person manages.
  def all_collections
    manageable_collections.order(:name)
  end

  def manageable_collections
    Collection.manageable_by(Current.user)
  end
end
