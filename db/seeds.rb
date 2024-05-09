# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
require 'json'

# USERS
#
default_user = ENV.fetch("USERNAME") { "admin@archyve.io" }
default_password = ENV.fetch("PASSWORD") { "password" }
model_endpoint = ENV.fetch("CHAT_ENDPOINT") { "http://localhost:11434" }

puts "Seeding database with USERNAME '#{default_user}', PASSWORD '********', and endpoint '#{model_endpoint}'..."

User.find_or_create_by!(email: default_user)  do |user|
  user.password = default_password
  user.admin = true
end

# CLIENTS
#
default_client = Client.find_by(name: "default")
default_client_id = ENV["DEFAULT_CLIENT_ID"]
default_api_key = ENV["DEFAULT_API_KEY"]

if default_client_id.present? && default_api_key.present?
  if default_client.nil?
    puts("Creating default client based on DEFAULT_CLIENT_ID and DEFAULT_API_KEY...")
    default_client = Client.create!(
      name: "default",
      client_id: default_client_id,
      api_key: default_api_key,
      user: User.first
    )
  elsif default_client.client_id != default_client_id || default_client.api_key != default_api_key
    Rails.info.logger("Updating default client ID and API key based on DEFAULT_CLIENT_ID and DEFAULT_API_KEY...")
    default_client.update!(client_id: default_client_id, api_key: default_api_key)
  else
    puts("Default client already exists with correct client ID and API key.")
  end
else
  puts("DEFAULT_CLIENT_ID and DEFAULT_API_KEY not set; not creating or updating default client.")
end

# SETTINGS
#
Setting.find_or_create_by!(key: "chat_model") do |setting|
  setting.value = ModelConfig.generation.default.last&.id
end

Setting.find_or_create_by!(key: "embedding_model") do |setting|
  setting.value = ModelConfig.embedding.default.last&.id
end

Setting.find_or_create_by!(key: "summarization_model") do |setting|
  setting.value = ModelConfig.generation.default.last&.id
end

# PROVISIONING
#
devel_model_servers = [
  {
    name: "localhost",
    provider: "ollama",
  }
]

devel_model_configs = [
  {
    name: "mistral:instruct",
    model_server: "localhost",
    model: "mistral:instruct",
    temperature: 0.1,
  },
  {
    name: "gemma:7b",
    model_server: "localhost",
    model: "gemma:7b",
    temperature: 0.2,
  },
  {
    name: "all-minilm",
    model_server: "localhost",
    model: "all-minilm",
    embedding: true,
  },
  {
    name: "nomic-embed-text",
    model_server: "localhost",
    model: "nomic-embed-text",
    embedding: true,
  }
]

provisioned_model_servers = JSON.parse(ENV.fetch("PROVISIONED_MODEL_SERVERS") {
  Rails.env == "development" ? JSON.generate(devel_model_servers) : '[]'
})

provisioned_model_configs = JSON.parse(ENV.fetch("PROVISIONED_MODEL_CONFIGS") {
  Rails.env == "development" ? JSON.generate(devel_model_configs) : '[]'
})


provisioned_model_servers_names = provisioned_model_servers.map { |ms| ms["name"] }
provisioned_model_config_names = provisioned_model_configs.map { |mc| mc["name"] }

ModelConfig.where(provisioned: true).where.not(name: provisioned_model_config_names).update(enabled: false, provisioned: false)
ModelServer.where(provisioned: true).where.not(name: provisioned_model_servers_names).update(enabled: false, provisioned: false)

provisioned_model_servers.each do |config|
  puts "provisioning model server for `#{config["name"]}` ..."

  ModelServer.find_or_create_by!(name: config["name"]).update(
    url: config.fetch("url") { model_endpoint },
    provider: config.fetch("provider"),
    default: config.fetch("default") { false },
    provisioned: true,
  )
end

provisioned_model_configs.each do |config|
  server = ModelServer.find_by(name: config.fetch("model_server", "localhost"))
  puts "provisioning model configuration for `#{config["name"]}` ..."

  ModelConfig.find_or_create_by!(name: config["name"], model_server: server).update(
    model: config.fetch("model") { config["name"] },
    temperature: config.fetch("temperature") { nil },
    embedding: config.fetch("embedding") { false },
    default: config.fetch("default") { false },
    provisioned: true,
  )
end

# DEV
#
if Rails.env == "development"
  if default_client
      puts <<~TEXT
      To authenticate with the default API client, set these headers:

      Authorization: Bearer #{default_client.api_key}
      X-Client-Id: #{default_client.client_id}

      E.g.:

      curl -v localhost:3300/v1/collections \\
        -H "Accept: application/json" \\
        -H "Authorization: Bearer #{default_client.api_key}" \\
        -H "X-Client-Id: #{default_client.client_id}"
    TEXT
  end
end
