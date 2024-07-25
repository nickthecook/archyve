module DocumentsHelper
  def state_text_for(document)
    text = case document.state
    when "errored" then "Error"
    else document.state.titleize
    end

    if document.current_step.present? && document.step_count.present?
      "#{text} #{document.current_step}/#{document.step_count}"
    else
      text
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
    when :bytes then 1000
    when "sentences" then 5
    when "paragraphs" then 1
    else 1
    end
  end

  def chunk_overlap(method)
    Setting.get("#{method}_chunk_overlap", user: current_user) ||
      Setting.get("#{method}_chunk_overlap", default: default_chunk_overlap(method))
  end

  def default_chunk_overlap(method)
    case method
    when :bytes then 200
    when "sentences" then 1
    when "paragraphs" then 0
    when "pages" then 0
    else 0
    end
  end
end
