module Graph
  class SummarizeCollectionEntities
    def initialize(collection, force_all: false)
      @collection = collection
      @force_all = force_all
    end

    def execute
      iteration = 1
      entities.each do |entity|
        Rails.logger.info("Summarizing entity '#{entity.name}' (#{iteration}/#{entity_count})...")
        next if entity.summary.present? && entity.summary_outdated == false && @force_all == false

        summarizer.summarize(entity)

        iteration += 1
      end
    end

    private

    def entities
      @entities ||= if @force_all
        @collection.graph_entities
      else
        @collection.graph_entities.where(summary: nil).or(@collection.graph_entities.where(summary_outdated: true))
      end
    end

    def entity_count
      @entity_count ||= @collection.graph_entities.count
    end

    def summarizer
      @summarizer ||= Graph::EntitySummarizer.new(Setting.entity_extraction_model, traceable: @collection)
    end
  end
end
