module V1
  class SearchController < ApiController
    def search
      return render json: { error: "No query given" }, status: :bad_request if query.blank?

      render json: { hits: }
    rescue StandardError => e
      Rails.logger.error "Error while searching for #{query}: #{e}\n#{e.backtrace.join("\n")}"

      render json: { error: e.message }, status: :internal_server_error
    end

    private

    def hits
      Api::GenerateSearchResults.new(
        @client.collections,
        base_url: request.base_url,
        browser_base_url:,
        num_results:,
        traceable: @client
      ).search(query)
    end

    def query
      @query ||= params[:q]
    end

    def num_results
      num_results = params[:num_results].to_i if params.include?(:num_results)
      num_results || Setting.get(:num_chunks_to_include, default: 10)
    end
  end
end
