class ModelServersController < ApplicationController
  before_action :set_model_server!, except: %i[create]

  def show
    @model_config = ModelConfig.new
  end

  def create
    @model_server = create_model_server

    respond_to do |format|
      format.html do
        if @model_server.valid?
          SyncModelsJob.perform_async(@model_server.id) if @model_server.provider == "ollama"

          flash[:notice] = "Inference server created."
        else
          flash[:alert] = @model_server.errors.full_messages.join(";  ")
        end

        redirect_to settings_path
      end
    end
  end

  def update
    return head :no_content if @model_server.update(model_server_params)

    render json: @model_server.errors, status: :unprocessable_entity
  end

  def destroy
    respond_to do |format|
      format.html do
        if @model_server.mark_as_deleted
          flash[:notice] = "Inference server deleted."
        else
          flash[:alert] = @model_server.errors.full_messages.join(";  ")
        end

        redirect_to settings_path
      end
    end
  end

  def activate
    @model_server.make_active

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = 'Inference server activated.'
        render turbo_stream: turbo_stream.replace(user_dom_id("notice"), partial: "shared/notice")
      end
      format.html do
        flash[:notice] = 'Model server activated.'
        redirect_to settings_path
      end
    end
  end

  def sync_models
    SyncModelsJob.perform_async(@model_server.id)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = 'Syncing models...'
        render turbo_stream: turbo_stream.replace(user_dom_id("notice"), partial: "shared/notice")
      end
    end
  end

  private

  def create_model_server
    existing_but_deleted_server = ModelServer.deleted.find_by(**model_server_find_params)

    if existing_but_deleted_server.present?
      existing_but_deleted_server.restore
      existing_but_deleted_server.update(api_key: model_server_find_params[:api_key])

      existing_but_deleted_server
    else
      ModelServer.create(model_server_params)
    end
  end

  def model_server_find_params
    # remove api_key, since encrypted fields won't be matched by find_by
    model_server_params.to_h.slice!(:api_key)
  end

  def model_server_params
    params.require(:model_server).permit(:name, :provider, :url, :api_key)
  end

  def set_model_server!
    @model_server = ModelServer.find(params[:id] || params[:model_server_id])
  end
end
