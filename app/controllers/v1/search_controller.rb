module V1
  class SearchController < ApiController
    def search
      query = params[:q]
      return render json: { "error": "No query given" }, status: :bad_request if query.blank?

      render json: { hits: Api::SearchMultiple.new(@client.collections, base_url: request.base_url).search(query) }
    end
  end
end
