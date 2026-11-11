# Reads a tool call whose arguments are an unclosed brace as no arguments.
#
# vLLM 1.5.1 streams `{` and nothing more when the model calls a tool that
# declares no parameters. RubyLLM keeps unparseable arguments as malformed and
# never runs the call, so the model asks for a list and gets nothing. Only an
# empty brace is repaired: a truncated argument list stays malformed, because
# calling a tool with arguments the model didn't finish sending is worse than
# not calling it.
module RubyLLM
  class Protocol
    class StreamAccumulator
      module EmptyToolArguments
        def streamed_arguments(tool_call, response)
          arguments = tool_call.arguments
          arguments.replace("{}") if arguments.is_a?(String) && arguments.strip == "{"

          super
        end
      end

      prepend EmptyToolArguments
    end
  end
end
