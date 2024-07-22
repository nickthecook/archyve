module Graph
  class ExtractDocumentEntities
    def initialize(document)
      @document = document
    end

    def extract
      iteration = 1
      @document.chunks.order(:id).each do |chunk|
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
  end
end
