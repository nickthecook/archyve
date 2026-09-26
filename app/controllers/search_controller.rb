class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @scope = Retrieval::Scope.from_params(params, user: Current.user)
    @outcome = @query.present? ? search : Retrieval::Outcome.new

    render Views::Search::Index.new(query: @query, outcome: @outcome, scope: @scope)
  end

  private

  # Retrieval itself lives in Retrieval::Search, which the chat tool calls too
  # — the access-control rules have to be the same object, not the same idea.
  # A failure comes back as an Outcome rather than raising, so an unreachable
  # embedding server degrades to a message instead of a 500.
  def search
    corpus = Retrieval::Corpus.new(user: Current.user, scope: @scope)
    Retrieval::Search.new(corpus:).call(@query)
  end
end
