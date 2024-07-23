module Graph
  class ExtractDocumentEntities
    def initialize(document, start_index = 0)
      @document = document
      @start_index = start_index
    end

    def extract
      iteration = 1
      chunks.each do |chunk|
        Rails.logger.info("Extracting entities from #{@document.filename}:#{chunk.id} (#{iteration}/#{chunk_count})...")

        extractor.extract(chunk)

        iteration += 1
      end
    end

    private

    def extractor
      @extractor ||= EntityExtractor.new(Setting.chat_model)
    end

    def chunk_count
      @chunk_count ||= @document.chunks.count
    end

    def chunks
      @chunks ||= @document.chunks.order(:id).offset(@start_index).where(entities_extracted: false)
    end
  end
end
