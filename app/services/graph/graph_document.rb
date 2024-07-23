module Graph
  class GraphDocument
    def initialize(document)
      @document = document
    end

    def graph
      @document.extracting_entities!
      ExtractDocumentEntities.new(@document).extract
      @document.extracted_entities!

      @document.summarizing_entities!
      SummarizeCollectionEntities.new(@document.collection).summarize
      @document.summarized_entities!

      @document.graphing_entities!
      GraphEntities.new(@document.collection).graph
      @document.graphed!
    end
  end
end
