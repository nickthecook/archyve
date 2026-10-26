module Settings
  # Nothing here may name who asked — see Views::Settings::Reviews::Show.
  class ReviewsController < ApplicationController
    require_role :admin

    def index
      listing = Reviews::Listing.new(params)
      page = listing.page

      render Views::Settings::Reviews::Index.new(
        page:, turns: Reviews::Listing.turns(page.records), facets: listing.facets, query: listing.query
      )
    end

    def show
      conversation = Conversation.find(params[:id])

      render Views::Settings::Reviews::Show.new(
        conversation:,
        messages: conversation.messages.includes(:inference_model, :feedback, segments: { hits: :document })
      )
    end
  end
end
