module Graph
  class SummarizeCollectionEntities
    def initialize(collection, force_all: false)
      @collection = collection
      @force_all = force_all

      @collection.update!(process_steps: entity_count)
    end

    def execute
      @collection.update!(state: :summarizing)

      entities.each_with_index do |entity, index|
        process_entity(entity, index)
      end

      @collection.update!(state: :summarized)
    rescue StandardError => e
      Rails.logger.error("#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")
      @collection.update!(state: :error)

      raise e
    end

    private

    def process_entity(entity, index)
      Rails.logger.info("Summarizing entity '#{entity.name}' (#{index}/#{entity_count})...")
      @collection.update!(process_step: index + 1)

      summarizer.summarize(entity)
    end

    def entities
      @entities ||= if @force_all
        @collection.graph_entities
      else
        @collection.graph_entities.where(summary: nil).or(@collection.graph_entities.where(summary_outdated: true))
      end
    end

    def entity_count
      @entity_count ||= entities.count
    end

    def summarizer
      @summarizer ||= Graph::EntitySummarizer.new(Setting.entity_extraction_model)
    end
  end
end
