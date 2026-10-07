module Settings
  # Where Archyve sends prompts. Admin-only, like everything under Settings —
  # there is no per-object grant here, deliberately: see the note on
  # InferenceServer about why the manageable_by trio is absent.
  class InferenceServersController < ApplicationController
    require_role :admin

    before_action :set_server, only: [:show, :edit, :update, :destroy, :check, :discover, :import]

    def index
      render Views::Settings::InferenceServers::Index.new(
        servers: InferenceServer.order(:name).includes(:inference_models)
      )
    end

    def show
      render Views::Settings::InferenceServers::Show.new(
        server: @server,
        embedded_chunk_count: Embedding.count,
        active_embedding: InferenceModel.active_embedding,
        corpus_model: Embedding.corpus_model
      )
    end

    # Without a type, offer the choice; with one, show that type's form. One
    # "Add server" entry point however many provider types exist — the same
    # shape SourcesController#new uses.
    def new
      if params[:type].blank?
        return render Views::Settings::InferenceServers::ChooseType.new(types: InferenceServer.creatable_types)
      end

      render Views::Settings::InferenceServers::New.new(server: build_server)
    end

    def create
      server = build_server
      server.assign_attributes(server_params(server))

      if server.save
        redirect_to settings_inference_server_path(server), notice: "Added “#{server.name}”."
      else
        render Views::Settings::InferenceServers::New.new(server:), status: :unprocessable_entity
      end
    end

    def edit
      render Views::Settings::InferenceServers::Edit.new(server: @server)
    end

    def update
      if @server.update(update_params(@server))
        redirect_to settings_inference_server_path(@server), notice: "Saved."
      else
        render Views::Settings::InferenceServers::Edit.new(server: @server), status: :unprocessable_entity
      end
    end

    # Deleting cascades to this server's models. It does not touch the vectors
    # they produced: embeddings.embedding_model is a free-text record of what
    # embedded each chunk, and stays true after the row that named it is gone.
    #
    # Refused when the cascade would take the archive's embedder with it — the
    # same rule the page greys the button out for, enforced where it counts.
    def destroy
      unless @server.destroy
        return redirect_to settings_inference_server_path(@server), alert: @server.removal_refusal
      end

      redirect_to settings_inference_servers_path, notice: "Removed “#{@server.name}”."
    end

    def check
      if @server.check!
        redirect_to settings_inference_server_path(@server), notice: "#{@server.name} answered."
      else
        redirect_to settings_inference_server_path(@server), alert: "Couldn't reach #{@server.name}."
      end
    end

    # The import picker. Discovery is a live call, so a server that has gone
    # away lands back on its own page with the reason rather than a blank list.
    def discover
      discovered = @server.check!
      return redirect_to settings_inference_server_path(@server), alert: unreachable_message unless discovered

      render Views::Settings::InferenceServers::Discover.new(
        server: @server,
        discovered: discovered,
        existing: @server.inference_models.pluck(:name),
        embedding_locked: Embedding.exists?,
        has_embedding_model: InferenceModel.embedding.exists?
      )
    end

    # Create one model per ticked box. Kinds come from the form, not from the
    # server: Ollama can say which of its models are embedders but an
    # OpenAI-compatible endpoint can't, so the picker always carries the answer.
    def import
      created, rejected = import_selected

      if rejected.any?
        redirect_to settings_inference_server_path(@server),
          alert: "Imported #{created}; skipped #{rejected.to_sentence}."
      else
        redirect_to settings_inference_server_path(@server),
          notice: "Imported #{created} #{'model'.pluralize(created)}."
      end
    end

    private

    def set_server
      @server = InferenceServer.find(params[:id])
    end

    # The type comes from the URL, so only types a person may actually add are
    # allowed — `constantize` on user input would otherwise instantiate any
    # class in the app. Same guard as SourcesController#build_source.
    def build_server
      type = params[:type].to_s
      unless InferenceServer.creatable_types.any? { |klass| klass.name == type }
        raise ActionController::BadRequest, "unknown inference server type"
      end

      type.constantize.new
    end

    # Flavour is permitted only for a type that has flavours, so a post naming
    # one for a server with no such setting is dropped rather than raising.
    def server_params(server)
      keys = [:name, :base_url, :api_key]
      keys << :flavour if server.flavours.any?
      params.require(:inference_server).permit(*keys)
    end

    # A blank key means "leave it alone": the form never echoes the stored key,
    # so submitting it unchanged would otherwise wipe it. Everything else is
    # taken as sent — a blank address means OpenAI itself, and a blank flavour
    # means "go back to detecting it".
    def update_params(server)
      permitted = server_params(server)
      permitted.except(:api_key).merge(permitted.slice(:api_key).compact_blank)
    end

    def unreachable_message
      "Couldn't reach #{@server.name}: #{@server.last_check_error}"
    end

    def import_selected
      created = 0
      rejected = []

      Array(params[:models]).reject(&:blank?).each do |name|
        kind = params.dig(:kinds, name).presence || "chat"
        attributes = attributes_for(name)

        if toolless_chat?(kind, attributes)
          rejected << "#{name} (can't call tools)"
          next
        end

        model = @server.inference_models.new(name:, kind:, **attributes)
        model.save ? created += 1 : rejected << "#{name} (#{model.errors.full_messages.to_sentence})"
      end

      [created, rejected]
    end

    # The same rule the picker greys a row out for, enforced where it counts:
    # disabling a checkbox is a claim about the page, not about the request.
    # A chat model that can't call tools can never reach the archive, so there
    # is nothing to import however the post was assembled.
    def toolless_chat?(kind, attributes)
      kind == "chat" && !attributes[:supports_tools]
    end

    # Capability figures come back through the form rather than being looked up
    # again: re-running discovery here would be a second round of HTTP calls to
    # answer a question that was already answered on the page being submitted.
    def attributes_for(name)
      {
        context_window: params.dig(:context_windows, name).presence,
        dimensions: params.dig(:dimensions, name).presence,
        supports_tools: params.dig(:supports_tools, name).present?
      }
    end
  end
end
