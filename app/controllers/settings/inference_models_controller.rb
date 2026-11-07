module Settings
  # Models on one server. Always nested: a model without a server has no
  # address to be reached at, so there is no top-level list of them.
  class InferenceModelsController < ApplicationController
    require_role :admin

    before_action :set_server
    before_action :set_model, only: [:edit, :update, :destroy]
    before_action :refuse_frozen_embedding, only: [:update]

    def new
      render Views::Settings::InferenceModels::New.new(
        server: @server,
        model: @server.inference_models.new(kind: :chat),
        embedding_locked: embedding_locked?
      )
    end

    def create
      model = @server.inference_models.new(model_params)

      if model.save
        redirect_to settings_inference_server_path(@server), notice: "Added #{model.name}."
      else
        render Views::Settings::InferenceModels::New.new(
          server: @server, model:, embedding_locked: embedding_locked?
        ), status: :unprocessable_content
      end
    end

    def edit
      render Views::Settings::InferenceModels::Edit.new(server: @server, model: @model)
    end

    def update
      if @model.update(model_params.except(:kind))
        redirect_to settings_inference_server_path(@server), notice: "Saved #{@model.name}."
      else
        render Views::Settings::InferenceModels::Edit.new(server: @server, model: @model),
          status: :unprocessable_content
      end
    end

    # Refusal is the model's own — see InferenceModel#removal_refusal, which the
    # cascade from a deleted server has to obey too. Editing a frozen embedder
    # is a different rule, and still belongs to refuse_frozen_embedding above.
    def destroy
      unless @model.destroy
        return redirect_to settings_inference_server_path(@server), alert: @model.removal_refusal
      end

      redirect_to settings_inference_server_path(@server), notice: "Removed #{@model.name}."
    end

    private

    def set_server
      @server = InferenceServer.find(params[:inference_server_id])
    end

    def set_model
      @model = @server.inference_models.find(params[:id])
    end

    # Changing a frozen embedder, as opposed to removing it: a model that is
    # renamed or re-dimensioned strands the vectors just as thoroughly.
    def refuse_frozen_embedding
      return unless @model.embedding? && Embedding.exists?

      redirect_to settings_inference_server_path(@server),
        alert: "#{Embedding.count} chunks are embedded with #{@model.name}. Changing the embedding model " \
               "means re-embedding the archive, which Archyve can't do yet."
    end

    def embedding_locked? = Embedding.exists?

    # `kind` permitted on create and dropped on update
    # an embedding model that became a chat model would orphan the corpus
    def model_params
      params.require(:inference_model)
        .permit(:name, :display_name, :kind, :dimensions, :context_window, :supports_tools, :enabled)
    end
  end
end
