require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Archyve
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    config.eager_load_paths << "#{root}/app/services"
    config.eager_load_paths << "#{root}/app/lib"
    config.autoload_paths << "#{root}/app/services"
    config.autoload_paths << Rails.root.join('app/lib')

    active_record_encryption = JSON.parse(ENV["ACTIVE_RECORD_ENCRYPTION"] || "{}")
    config.active_record.encryption.primary_key = active_record_encryption["primary_key"]
    config.active_record.encryption.deterministic_key = active_record_encryption["deterministic_key"]
    config.active_record.encryption.key_derivation_salt = active_record_encryption["key_derivation_salt"]

    config.embedding_endpoint = ENV.fetch("EMBEDDING_ENDPOINT") { "http://localhost:11434" }
    config.embedding_model = ENV.fetch("EMBEDDING_MODEL") { "all-minilm" }
    config.summarization_endpoint = ENV.fetch("SUMMARIZATION_ENDPOINT") { "http://localhost:11435" }
    config.summarization_model = ENV.fetch("SUMMARIZATION_MODEL") { "mistral:instruct" }

    config.run_sidekiq = ENV.fetch("RUN_SIDEKIQ", "false") == "true"
    Sidekiq.logger.class.include ActiveSupport::LoggerSilence
    config.sidekiq_retries = 3

    require 'active_graph/railtie'
    config.neo4j.driver.url = ENV.fetch('NEO4J_URL') { 'neo4j://localhost:7687' }
    config.neo4j.driver.username = ENV.fetch('NEO4J_USERNAME') { 'neo4j' }
    config.neo4j.driver.password = ENV.fetch('NEO4J_PASSWORD') { 'password' }
  end
end
