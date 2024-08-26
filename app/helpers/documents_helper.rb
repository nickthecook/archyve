module DocumentsHelper
  def state_label_for(document)
    state_text = state_text_for(document)
    return state_text unless state_text.end_with?("ing")

    if document.process_step.present? && document.process_steps.present?
      "#{state_text} (#{document.process_step}/#{document.process_steps})"
    else
      state_text
    end
  end

  def state_text_for(document)
    case document.state
    when "errored" then "Error"
    else document.state.titleize
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
