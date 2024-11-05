module Graph
  class ExtractChunkEntities
    def initialize(chunk)
      @chunk = chunk
      @document = chunk.document
    end

    def execute
      return if @document.stop_jobs

      extract_entities
      update_document_state

      @document.collection.touch(:updated_at) # so Collections#show shows an updated entity count
    end

    private

    def extract_entities
      Rails.logger.info("Extracting entities from #{@document.filename}:#{@chunk.id}...")

      @chunk.update!(entities_extracted: false)
      extractor.extract(@chunk)
      @chunk.update!(entities_extracted: true)

      @document.touch(:updated_at)
    end

    def update_document_state
      chunk_count = @document.chunks.count
      return unless @document.chunks.embedded.count == chunk_count && @document.chunks.extracted.count == chunk_count

      SummarizeCollectionJob.perform_async(@document.collection.id)
      CleanCollectionEntitiesJob.perform_async(@document.collection.id)
    end

    def extractor
      @extractor ||= EntityExtractor.new(entity_extraction_model)
    end

    def entity_extraction_model
      @entity_extraction_model ||= ModelConfig.find(entity_extraction_model_id)
    end

    def entity_extraction_model_id
      @document.collection.entity_extraction_model&.id ||
        Setting.get("entity_extraction_model")
    end
  end
end
