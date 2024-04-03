class SearchController < ApplicationController
  include ActionView::RecordIdentifier

  def index
    @collections = current_user.collections
  end

  def search
    query = params[:query]
    dom_id = "search_multiple_results"
    collection_ids = current_user.collections.select(:id).map(&:id)

    SearchMultipleJob.perform_async(collection_ids, query, dom_id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            dom_id,
            partial: "search_multiple_results",
            locals: { query_id: dom_id }
          ),
          turbo_stream.replace(
            "search_form",
            partial: "search_form",
            locals: { collection: @collection, query: }
          ),
        ]
      end
    end
  end
end
