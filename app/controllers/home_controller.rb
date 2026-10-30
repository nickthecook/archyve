class HomeController < ApplicationController
  def index
    render Views::Home::Index.new(
      stats: stats,
      models: InferenceModel.choosable_for_chat,
      model: InferenceModel.default_chat,
      unavailable: Chat::Availability.reason_for(Current.user)
    )
  end

  private

  # Nil until somebody configures a server; the landing says so rather than
  # inventing a default that nothing is actually talking to.
  def embedding_model
    @embedding_model ||= InferenceModel.active_embedding
  end

  def stats
    {
      collections: Collection.count,
      documents: Document.count,
      embedding_model: embedding_model&.name,
      host: embedding_model&.inference_server&.base_url.presence&.then { |url| URI(url).host },
      last_chat: nil
    }
  end
end
