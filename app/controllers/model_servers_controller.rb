class ModelServersController < ApplicationController
  before_action :set_model_server!, only: [:update, :destroy, :activate]

  def create
    @model_server = ModelServer.new(model_server_params)

    respond_to do |format|
      format.html do
        if @model_server.save
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
        if @model_server.destroy
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

  private

  def model_server_params
    params.require(:model_server).permit(:name, :provider, :url)
  end

  def set_model_server!
    @model_server = ModelServer.find(params[:id] || params[:model_server_id])
  end
end
