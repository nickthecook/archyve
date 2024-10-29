class SyncModelsJob
  include Sidekiq::Job

  def perform(model_server_id)
    model_server = ModelServer.find(model_server_id)

    Ollama::SyncModels.new(model_server).execute
  end
end
