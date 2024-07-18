module V1
  class ChatController < ApiController
    def chat
      return render json: { error: "No prompt given" }, status: :bad_request if prompt.blank?

      render json: Api::ChatResponse.new(
        prompt,
        model:,
        augment:,
        collections:,
        api_client: @client
      ).respond, status: :ok
    rescue ActiveRecord::RecordNotFound, Api::ModelNotFoundError => e
      render json: { error: e }, status: :not_found
    rescue StandardError => e
      render json: { error: e }, status: :internal_server_error
    end

    private

    def collections
      chat_params[:collections]&.split(",")&.map { |id| Collection.find(id) }
    end

    def augment
      chat_params[:augment] == "true"
    end

    def model
      chat_params[:model]
    end

    def prompt
      chat_params[:prompt]
    end

    def chat_params
      @chat_params ||= params.slice(:prompt, :model, :augment, :collections)
    end
  end
end
