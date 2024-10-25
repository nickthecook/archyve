FactoryBot.define do
  factory :model_config do
    name { "Mixalot" }
    model { "mixalot:latest" }
    temperature { 0.1 }
    embedding { false }
    vision { false }
    provisioned { false }
    available { true }
    model_server { nil }
    context_window_size { nil }
  end
end
