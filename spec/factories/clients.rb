FactoryBot.define do
  factory :client do
    name { Faker::Alphanumeric.alpha }
    user { association(:user) }
    client_id { Client.new_client_id }
    api_key { Client.new_api_key }
  end
end
