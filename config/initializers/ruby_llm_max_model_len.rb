# Carries a served context length through RubyLLM's model list.
#
# An OpenAI-compatible /v1/models says only what each model is called, so
# RubyLLM fills context_window from its own id-pattern registry — which
# recognises nothing a local vLLM serves, and falls back to 4,096. vLLM reports
# the real figure as `max_model_len` on every entry, and it is the better
# number twice over: it is what the server was *started* with, which truncates
# whatever the weights could have managed.
#
# RubyLLM's parser keeps only `object` and `owned_by` from each entry, so this
# puts it in metadata for InferenceServers::OpenAI#describe to prefer. Same
# shape, and the same reason, as config/initializers/ruby_llm_token_count.rb:
# the field is on the wire and the gem drops it.
#
# Absent for OpenAI itself, which doesn't send it — so nil here means "the
# endpoint didn't say", and the registry answer stands.
module RubyLLM
  module Providers
    class OpenAI
      module MaxModelLen
        def parse_list_models_response(response, slug, capabilities)
          lengths = Array(response.body["data"]).to_h { [it["id"], it["max_model_len"]] }

          super.each { it.metadata[:max_model_len] = lengths[it.id] }
        end
      end

      prepend MaxModelLen
    end
  end
end
