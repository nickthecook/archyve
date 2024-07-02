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
    Rails.info.logger("Updating default client ID and API key based on DEFAULT_CLIENT_ID and DEFAULT_API_KEY...")
    default_client.update!(client_id: default_client_id, api_key: default_api_key)
  else
    puts("Default client already exists with correct client ID and API key.")
  end
else
  puts("DEFAULT_CLIENT_ID and DEFAULT_API_KEY not set; not creating or updating default client.")
end


# PROVISIONING
#
def provision_from_env(schema, env_var, identifier='name', &block)
  known_columns = schema.column_names
  unless ['available', 'provisioned'].all? { |required| known_columns.include? required }
    return puts("WARNING: #{schema.table_name} does not support provisioning. Skipping...")
  end

  provisioned_records = if ENV[env_var].present?
    JSON.parse(ENV[env_var])
  elsif Rails.env == "development" and block_given?
    block.call
  else
    []
  end

  unless provisioned_records.is_a?(Array)
    return puts("WARNING: The JSON value prodived by $#{env_var} is invalid for provisioning. Skipping...")
  end
  provisioned_records.select! do |record|
    record.try(:keys).try(:include?, identifier)
  end

  provisioned_identifiers = provisioned_records.map { |mc| mc[identifier] }
  schema.where(provisioned: true)
        .where.not(name: provisioned_identifiers)
        .update(available: false, provisioned: false)

  provisioned_records.each do |fields|
    puts "provisioning #{schema.table_name} with `#{fields[identifier]}` ..."
  
    schema.find_or_initialize_by(**{ identifier => fields[identifier] })
          .update!(**fields.slice(*known_columns), provisioned: true)
  end
rescue JSON::ParserError => e
  puts "WARNING: Failed to provision #{schema.table_name}\n#{e}"
end

provision_from_env ModelServer, "PROVISIONED_MODEL_SERVERS" do
  [
    {
      "name" => "localhost",
      "url" => "http://localhost:11434",
      "provider" => "ollama",
    }
  ]
end

ModelServer.last.make_active if ModelServer.active_server.nil?

provision_from_env ModelConfig, "PROVISIONED_MODEL_CONFIGS" do
  [
    {
      "name" => "mistral:instruct",
      "model" => "mistral:instruct",
      "temperature" => 0.1,
    },
    {
      "name" => "gemma:7b",
      "model" => "gemma:7b",
      "temperature" => 0.2,
    },
    {
      "name" => "nomic-embed-text",
      "model" => "nomic-embed-text",
      "embedding" => true,
    }
  ]
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

Setting.find_or_create_by!(key: "num_chunks_to_include") do |setting|
  setting.value = 5
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
