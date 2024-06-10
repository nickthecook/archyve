module V1
  class SearchController < ApiController
    def search
      query = params[:q]
      return render json: { "error": "No query given" }, status: :bad_request if query.blank?

      render json: { hits: Api::SearchMultiple.new(@client.collections, base_url:).search(query) }
    rescue StandardError => e
      Rails.logger.error "Error while searching for #{query}: #{e}"

      render json: { error: e.message }, status: :internal_server_error
    end
  end
end
