class SummarizeEntityJob
  include Sidekiq::Job

  def perform(entity_id)
    entity = GraphEntity.find(entity_id)

    Graph::EntitySummarizer.new(Setting.entity_extraction_model).summarize(entity)
  end
end
