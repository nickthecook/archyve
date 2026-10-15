# Reads a tool call whose arguments are an unclosed brace as no arguments.
#
# vLLM 1.5.1 streams `{` and nothing more when the model calls a tool that
# declares no parameters, and RubyLLM's JSON.parse of that fragment raises —
# taking down a turn that was about to answer. Only an empty brace is repaired:
# a truncated argument list still raises, because calling a tool with arguments
# the model didn't finish sending is worse than not calling it.
module RubyLLM
  class StreamAccumulator
    module EmptyToolArguments
      def tool_calls_from_stream
        tool_calls.each_value do |call|
          arguments = call.arguments
          arguments.replace("{}") if arguments.is_a?(String) && arguments.strip == "{"
        end

        super
      end
    end

    prepend EmptyToolArguments
  end
end
