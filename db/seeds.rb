# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

User.find_or_create_by!(email: "nickthecook@gmail.com")  do |user|
  user.password = "password"
end

ModelServer.find_or_create_by!(name: "SHARD") do |ms|
  ms.url = "http://localhost:11434"
  ms.provider = "ollama"
end

ModelConfig.find_or_create_by!(name: "mistral:7b") do |mc|
  mc.model = "mistral:7b"
  mc.temperature = 0.1
  mc.model_server = ModelServer.first
end

ModelConfig.find_or_create_by!(name: "gemma:7b") do |mc|
  mc.model = "gemma:7b"
  mc.temperature = 0.2
  mc.model_server = ModelServer.first
end

Conversation.find_or_create_by!(title: "Test Conversation", user_id: User.first.id) do |c|
  c.model_config = ModelConfig.first
end

Message.find_or_create_by!(content: "Hello, world!") do |msg|
  msg.conversation = Conversation.first
  msg.author = User.first
end
