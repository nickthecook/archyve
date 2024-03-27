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
model_endpoint = ENV.fetch("CHAT_ENDPOINT") { "https://localhost:11434/v1/" }

puts "Seeding database with USERNAME '#{default_user}', PASSWORD '********', and endpoint '#{model_endpoint}'..."

User.find_or_create_by!(email: default_user)  do |user|
  user.password = default_password
  user.admin = true
end

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
