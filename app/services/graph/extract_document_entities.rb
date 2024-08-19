module Graph
  class ExtractDocumentEntities
    def initialize(document, start_index: 0, force_extraction: false)
      @document = document
      @start_index = start_index
      @force_extraction = force_extraction

      @document.update!(process_steps: chunk_count)
    end

    def execute
      chunks.each_with_index do |chunk, index|
        process_chunk(chunk, index)
      end
    rescue StandardError => e
      Rails.logger.error("#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")
      @document.error!

      raise e
    end

    private

    def process_chunk(chunk, index)
      Rails.logger.info("Extracting entities from #{@document.filename}:#{chunk.id} (#{index}/#{chunk_count})...")
      @document.update!(process_step: index + 1)

      return unless chunk.entities_extracted == false || @force_extraction

      chunk.update!(entities_extracted: false)
      extractor.extract(chunk)
      chunk.update!(entities_extracted: true)
    end

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
