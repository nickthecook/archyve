# RubyLLM configuration.
#
# Provider settings are deliberately absent. They live on InferenceServer rows
# and are applied per call through InferenceServer#llm_context, for two reasons:
# an initializer runs before the database is readable, so it could never reflect
# those rows; and RubyLLM's provider config is global and single-slot — one
# `config.ollama_api_base` for the whole process — which two Ollama hosts cannot
# share. A RubyLLM::Context carries its own copy of the config, so each server
# speaks for itself.
#
# We use the modern RubyLLM API (RubyLLM.embed / RubyLLM.chat), NOT the legacy
# acts_as integration — the acts_as deprecation warning on boot is expected.
RubyLLM.configure do |config|
  config.logger = Rails.logger
end
