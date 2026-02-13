FactoryBot.define do
  factory :document do
    chunks { [] }
    user { association(:user) }
    collection { association(:collection) }
    link { "https://www.gnu.org/gnu/manifesto.html" }
    filename { "spec/fixtures/files/gnu_manifesto.md" }
    state { :chunked }
    vector_id { nil } # TODO: we probably don't need this
    chunking_profile { association(:chunking_profile) }

    trait :with_file do
      file { Rails.root.join(filename) }
    end
  end

  factory :fact, parent: :document, class: "Fact" do
    filename { "fact-#{Time.current.to_i}.txt" }
    link { nil }

    trait :with_file do
      after(:build) do |fact|
        fact.file.attach(
          io: StringIO.new("This is a fact."),
          filename: fact.filename,
          content_type: "text/plain"
        )
      end
    end
  end
end
