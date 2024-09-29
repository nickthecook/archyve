module DocumentsHelper
  def state_text_for(document)
    case document.state
    when "errored" then "Error"
    else document.state.titleize
    end
  end

  def title_for(document)
    if document.title.presence
      document.title
    else
      document.filename
    end
  end

  def chunks_completed_label_for(total_chunks, completed_chunks, label_name)
    if total_chunks.zero?
      "Not #{label_name}"
    elsif total_chunks == completed_chunks
      label_name.titleize
    else
      "#{label_name.titleize}: #{completed_chunks}/#{total_chunks}"
    end
  end

  def state_error?(document)
    document.errored?
  end

  def chunking_method_options
    Chunkers::CHUNKING_METHODS.map do |chunking_method|
      [chunking_method[:id], chunking_method[:name]]
    end
  end

  def default_chunking_method
    :bytes
  end

  def default_chunk_size(method)
    case method
    when :bytes then 1000
    when "sentences" then 5
    else 1
    end
  end

  def default_chunk_overlap(method)
    case method
    when :bytes then Setting.get("chunk_bytes_overlap", default: 0)
    when "sentences" then 1
    when "paragraphs" then 0
    when "pages" then 0
    else 0
    end
  end
end
