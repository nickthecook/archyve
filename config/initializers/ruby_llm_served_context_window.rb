# Carries a served context length through RubyLLM's model list, which keeps only
# `object` and `owned_by`. Each server names it differently; see
# InferenceServers::OpenAI#context_window_for for why it beats the registry.
module RubyLLM
  module Providers
    class OpenAI
      module ServedContextWindow
        FIELDS = %w[max_model_len max_input_tokens].freeze

        def parse_list_models_response(response, slug, capabilities)
          lengths = Array(response.body["data"]).to_h { [it["id"], it.values_at(*FIELDS).compact.first] }

          super.each { it.metadata[:served_context_window] = lengths[it.id] }
        end
      end

      prepend ServedContextWindow
    end
  end
end
