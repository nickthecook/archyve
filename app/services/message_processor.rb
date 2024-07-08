class MessageProcessor
  attr_reader :input, :output

  def initialize
    @in_code_block = false
    @backticks = 0
    @input = ""
    @output = ""
  end

  # rubocop:disable all
  def append(str)
    @input += str
    ret = ""
    str.each_char do |char|
      if char == "`"
        @newline = false
        @backticks += 1
        ret += "`"
        if @backticks == 3
          @backticks = 0
          @in_code_block = !@in_code_block
        end
      else
        @backticks = 0
        case char
        when " "
          next if @newline && ! @in_code_block
          ret += @in_code_block ? "&nbsp;" : " "
        when "\n"
          @newline = true
          ret += "<br>\n"
        else
          @newline = false
          ret += char
        end
      end
    end

    @output += ret
    ret
  end
  # rubocop:enable all
end
