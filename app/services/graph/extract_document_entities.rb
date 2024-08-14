module Graph
  class ExtractDocumentEntities
    def initialize(document, start_index: 0, force_extraction: false)
      @document = document
      @start_index = start_index
      @force_extraction = force_extraction
    end

    def execute
      iteration = 1
      chunks.each do |chunk|
        Rails.logger.info("Extracting entities from #{@document.filename}:#{chunk.id} (#{iteration}/#{chunk_count})...")

        if chunk.entities_extracted == false || @force_extraction
          chunk.update!(entities_extracted: false)
          extractor.extract(chunk)
          chunk.update!(entities_extracted: true)
        end

        iteration += 1
      end
    end

    private

    def extractor
      @extractor ||= EntityExtractor.new(entity_extraction_model, traceable: @document)
    end

    def chunk_count
      @chunk_count ||= @document.chunks.count
    end

    def chunks
      @chunks ||= @document.chunks.order(:id).offset(@start_index)
    end

    def entity_extraction_model
      @entity_extraction_model ||= ModelConfig.find(entity_extraction_model_id)
    end

    def entity_extraction_model_id
      Setting.get("entity_extraction_model", default: Setting.chat_model.id)
    end
  end
end
