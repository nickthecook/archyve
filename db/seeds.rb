# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

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
    Rails.logger.info("Updating default client ID and API key based on DEFAULT_CLIENT_ID and DEFAULT_API_KEY...")
    default_client.update!(client_id: default_client_id, api_key: default_api_key)
  else
    puts("Default client already exists with correct client ID and API key.")
  end
else
  puts("DEFAULT_CLIENT_ID and DEFAULT_API_KEY not set; not creating or updating default client.")
end


# PROVISIONING
#
dev_model_servers = [
  {
    "name" => "localhost",
    "url" => "http://localhost:11434",
    "provider" => "ollama",
  }
]

dev_model_configs = [
  {
    "name" => "llama3.1:8b",
    "model" => "llama3.1:8b",
    "temperature" => 0.1,
  },
  {
    "name" => "phi3:latest",
    "model" => "phi3:latest",
    "temperature" => 0.1,
  },
  {
    "name" => "nomic-embed-text",
    "model" => "nomic-embed-text",
    "embedding" => true,
  }
]

provisioned_model_servers = if ENV["PROVISIONED_MODEL_SERVERS"].present?
  JSON.parse(ENV["PROVISIONED_MODEL_SERVERS"])
elsif Rails.env == "development"
  dev_model_servers
else
  []
end

provisioned_model_configs = if ENV["PROVISIONED_MODEL_CONFIGS"].present?
  JSON.parse(ENV["PROVISIONED_MODEL_CONFIGS"])
elsif Rails.env == "development"
  dev_model_configs
else
  []
end

provisioned_model_servers_names = provisioned_model_servers.map { |ms| ms["name"] }
provisioned_model_config_names = provisioned_model_configs.map { |mc| mc["name"] }

ModelConfig.where(provisioned: true).where.not(name: provisioned_model_config_names).update(available: false, provisioned: false)
ModelServer.where(provisioned: true).where.not(name: provisioned_model_servers_names).update(available: false, provisioned: false)

model_server_fields = ModelServer.column_names
provisioned_model_servers.each do |fields|
  fields.slice!(*model_server_fields)
  puts "provisioning model server for `#{fields}` ..."

  ModelServer.find_or_initialize_by(name: fields["name"]).update!(**fields, provisioned: true)
end

ModelServer.last.make_active if ModelServer.active_server.nil?

model_config_fields = ModelConfig.column_names
provisioned_model_configs.each do |fields|
  server = fields["server"]
  fields.slice!(*model_config_fields)
  puts "provisioning model configuration for `#{fields}` ..."

  model_config = ModelConfig.find_or_initialize_by(name: fields["name"])
  model_config.update!(**fields, provisioned: true)
  if server
    model_server = ModelServer.find_by(name: server)
    model_config.update!(model_server:)
  end
end


# SETTINGS
#
Setting.find_or_create_by!(key: "chat_model") do |setting|
  setting.value = ModelConfig.generation.last&.id
end

Setting.find_or_create_by!(key: "embedding_model") do |setting|
  setting.value = ModelConfig.embedding.last&.id
end

Setting.find_or_create_by!(key: "summarization_model") do |setting|
  setting.value = ModelConfig.generation.last&.id
end

Setting.find_or_create_by!(key: "entity_extraction_model") do |setting|
  setting.value = ModelConfig.generation.last&.id
end

Setting.find_or_create_by!(key: "num_chunks_to_include") do |setting|
  setting.value = 5
end

Setting.find_or_create_by!(key: "distance_ratio_threshold") do |setting|
  setting.value = 0.2
end

Setting.find_or_create_by!(key: "normalized_search_distance_ceiling") do |setting|
  setting.value = 0.5
end

Setting.find_or_create_by!(key: "num_chunks_to_include") do |setting|
  setting.value = 10
end

Setting.find_or_create_by!(key: "opp_num_conversation_title_chars") do |setting|
  setting.value = 60
end

Setting.find_or_create_by!(key: "opp_num_recent_convos_for_match") do |setting|
  setting.value = 10
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
