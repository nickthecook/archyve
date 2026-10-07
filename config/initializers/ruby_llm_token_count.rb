# Puts the per-chunk token count back on a streamed chunk.
#
# A server that batches tokens into one SSE event breaks counting deltas as
# tokens: vLLM flushes on a ~55ms clock with however many tokens it produced in
# between, so a host streaming 60 tok/s reports a steady ~18 whatever model it
# is running. Asked for them (`return_token_ids`, see
# InferenceServers::OpenAI#stream_params) it names the tokens in every event —
# and RubyLLM's chunk builder drops the field, so this carries it through to
# Chat::Pace.
#
# Nil for a provider that doesn't send it, which Pace reads as one token per
# delta — right for Ollama, which streams exactly that.
RubyLLM::Chunk.class_eval { attr_accessor :streamed_token_count }

module RubyLLM
  module Providers
    class OpenAI
      module StreamedTokenCount
        def build_chunk(data)
          super.tap { it.streamed_token_count = data.dig("choices", 0, "token_ids")&.size }
        end
      end

      prepend StreamedTokenCount
    end
  end
end
