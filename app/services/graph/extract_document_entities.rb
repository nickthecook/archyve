module Graph
  class ExtractDocumentEntities
    def initialize(document, start_index: 0, force_extraction: false)
      @document = document
      @start_index = start_index
      @force_extraction = force_extraction
    end

    def extract
      iteration = 1
      chunks.each do |chunk|
        @document.update!(current_step: iteration, step_count: chunk_count)
        Rails.logger.info("Extracting entities from #{@document.filename}:#{chunk.id} (#{iteration}/#{chunk_count})...")

        if chunk.entities_extracted == false || @force_extraction
          chunk.update!(entities_extracted: false)
          extractor.extract(chunk)
          chunk.update!(entities_extracted: true)
        end

        iteration += 1
      end
      @document.update!(current_step: nil, step_count: nil)
    end

    private

    def extractor
      @extractor ||= EntityExtractor.new(Setting.chat_model)
    end

    def chunk_count
      @chunk_count ||= @document.chunks.count
    end

    def chunks
      @chunks ||= @document.chunks.order(:id).offset(@start_index)
    end
  end
end
