# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

default_user = ENV.fetch("USERNAME") { "admin@archyve.io" }
default_password = ENV.fetch("PASSWORD") { "password" }
model_endpoint = ENV.fetch("CHAT_ENDPOINT") { "http://localhost:11434" }

puts "Seeding database with USERNAME '#{default_user}', PASSWORD '********', and endpoint '#{model_endpoint}'..."

User.find_or_create_by!(email: default_user)  do |user|
  user.password = default_password
  user.admin = true
end

if Rails.env == "development"
  ModelServer.find_or_create_by!(name: "localhost") do |ms|
    ms.url = model_endpoint
    ms.provider = "ollama"
  end

  ModelConfig.find_or_create_by!(name: "mistral:instruct", model_server: ModelServer.first) do |mc|
    mc.model = "mistral:instruct"
    mc.temperature = 0.1
  end

  ModelConfig.find_or_create_by!(name: "gemma:7b", model_server: ModelServer.first) do |mc|
    mc.model = "gemma:7b"
    mc.temperature = 0.2
  end

  ModelConfig.find_or_create_by!(name: "all-minilm", model_server: ModelServer.first) do |mc|
    mc.model = "all-minilm"
    mc.embedding = true
  end

  ModelConfig.find_or_create_by!(name: "nomic-embed-text", model_server: ModelServer.first) do |mc|
    mc.model = "nomic-embed-text"
    mc.embedding = true
  end

  default_client = Client.find_by(name: "default")

  if default_client.nil?
    default_client = Client.create!(
      name: "default",
      client_id: Client.new_client_id,
      api_key: Client.new_api_key,
      user: User.first
    )
  end

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
