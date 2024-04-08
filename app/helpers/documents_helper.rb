module DocumentsHelper
  def state_text_for(document)
    case document.state
    when "errored" then "Error"
    else document.state.capitalize
    end
  end

  def state_error?(document)
    document.errored?
  end

  def chunking_method_options
    Chonker::CHUNKING_METHODS.keys.map do |chunking_method|
      [chunking_method, chunking_method]
    end
  end

  def default_chunking_method
    :bytes
  end

  def default_chunk_size(method)
    case method
    when :bytes then 200
    when "sentences" then 5
    when "paragraphs" then 1
    else 1
    end
  end

  def default_chunk_overlap(method)
    case method
    when :bytes then 50
    when "sentences" then 1
    when "paragraphs" then 0
    when "pages" then 0
    else 0
    end
  end
end
