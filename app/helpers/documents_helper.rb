module DocumentsHelper
  def state_text_for(document)
    puts "STATE! #{document.state}"
    case document.state
    when "errored" then "Error"
    else document.state.capitalize
    end
  end

  def state_error?(document)
    document.errored?
  end
end
