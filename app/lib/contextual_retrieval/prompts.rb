module ContextualRetrieval
  class Prompts
    CONTEXTUALIZE_CHUNK_PROMPT = <<~PROMPT.freeze
      <document>
      <%= document_content >
      </document>
      Here is the chunk we want to situate within the whole document
      <chunk>
      <%= chunk_content %>
      </chunk>
      Please give a short succinct context to situate this chunk within the overall document for the purposes of improving search retrieval of the chunk. Answer only with the succinct context and nothing else.
    PROMPT
  end
end
