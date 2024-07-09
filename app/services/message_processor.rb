class MessageProcessor
  attr_reader :input, :output

  def initialize
    @in_code_block = false
    @backticks = 0
    @newline = false
    @input = ""
    @output = ""
  end

  # rubocop:disable all
  def append(str)
    @input += str.dup
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
          if @newline && ! @in_code_block
            next
          elsif @newline && @in_code_block
            ret += "&nbsp;"
          else
            ret += " "
          end
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
    [ret, str]
  end
  # rubocop:enable all
end
