module ContextualRetrieval
  class Prompts
    PRELOAD_DOCUMENT_PROMPT = <<~PROMPT.freeze
      Here is a document within which we want to contextualize a chunk of text:

      -DOCUMENT-
      <%= document_content %>
      - END DOCUMENT-

    PROMPT

    CONTEXTUALIZE_CHUNK_PROMPT = <<~PROMPT.freeze
      Here is the text we want to situate within the whole document:

      -TEXT-
      <%= chunk_content %>
      -END TEXT-

      What is the context in which this text appears in the document? What was being discussed at the time? What section or chapter did it appear in? Answer only with the context and nothing else.
    PROMPT

    CONTEXTUALIZE_CHUNK_PROMPT_FULLDOC = <<~PROMPT.freeze
      Here is a document within which we want to situate a chunk of text:

      -DOCUMENT-
      <%= document_content %>
      - END DOCUMENT-

      Here is the text we want to situate within the whole document:

      -TEXT-
      <%= chunk_content %>
      -END TEXT-

      What is the context in which this text appears in the document? What was being discussed at the time? What section or chapter did it appear in? Answer only with the context and nothing else.
    PROMPT
  end
end
