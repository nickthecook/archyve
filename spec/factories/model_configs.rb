FactoryBot.define do
  factory :model_config do
    name { "Mixalot" }
    model { "mixalot:latest" }
    temperature { 0.1 }
    embedding { false }
    provisioned { false }
    available { true }
  end
end
