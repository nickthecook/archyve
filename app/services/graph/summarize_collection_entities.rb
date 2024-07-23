module Graph
  class SummarizeCollectionEntities
    def initialize(collection, force_all: false, traceable: nil)
      @collection = collection
      @force_all = force_all
      @traceable = traceable
    end

    def summarize
      iteration = 1
      @collection.entities.each do |entity|
        Rails.logger.info("Summarizing entity '#{entity.name}' (#{iteration}/#{entity_count})...")
        next if entity.summary.present? && @force_all == false

        summarizer.summarize(entity)

        iteration += 1
      end
    end

    private

    def entity_count
      @entity_count ||= @collection.entities.count
    end

    def summarizer
      @summarizer ||= Graph::EntitySummarizer.new(Setting.chat_model, traceable: @traceable)
    end
  end
end
