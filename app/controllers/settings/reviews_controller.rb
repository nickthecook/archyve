module Settings
  # Nothing here may name who asked — see Views::Settings::Reviews::Show.
  class ReviewsController < ApplicationController
    require_role :admin

    def index
      listing = Reviews::Listing.new(params)

      respond_to do |format|
        format.html { render_page(listing) }
        format.csv do
          send_data Reviews::Export.new(listing.rows).to_csv,
            type: :csv, filename: "archyve-review-#{Date.current.iso8601}.csv"
        end
      end
    end

    def show
      conversation = Conversation.find(params[:id])

      render Views::Settings::Reviews::Show.new(
        conversation:,
        messages: conversation.messages.includes(:inference_model, :feedback, segments: { hits: :document })
      )
    end

    private

    def render_page(listing)
      page = listing.page

      render Views::Settings::Reviews::Index.new(
        page:, turns: Reviews::Listing.turns(page.records), facets: listing.facets, query: listing.query
      )
    end
  end
end
