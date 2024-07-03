FactoryBot.define do
  factory :chunking_profile do
    # 'method' is a method on Object which conflicts with the attribute; pass it in for now
    # TODO: rename the column 'chunking_profile'
    # method { "bytes" }
    size { 200 }
    overlap { 50 }
  end
end
