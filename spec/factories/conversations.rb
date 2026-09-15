FactoryBot.define do
  factory :conversation do
    association :user
    title { "A chat" }
    scope { {} }

    # Drawing on one collection, in the c[]/doc wire format.
    trait :scoped do
      transient { collection { nil } }
      scope { { "c" => [collection&.slug || "handbook"] } }
    end

    # Drawing on nothing: the picker with everything unticked. An empty `c` is
    # not the same spec as no `c` — see Retrieval::Scope.
    trait :no_collections do
      scope { { "c" => [] } }
    end
  end

  factory :message do
    association :conversation
    role { "user" }
    position { 1 }
  end

  factory :segment do
    association :message
    position { 1 }
    kind { "text" }
    content { "Some prose." }

    factory :thinking_segment do
      kind { "thinking" }
      content { "The user is asking about rotation. We should check the handbook." }
    end

    factory :retrieval_segment do
      kind { "retrieval" }
      content { nil }
      queries { ["credential rotation"] }
      candidate_count { 12 }
    end
  end

  factory :hit do
    association :segment, factory: :retrieval_segment
    association :chunk
    document { chunk.document }
    handle { 1 }
    distance { 0.2 }
    score { 0.016 }
    snippet { "Production datastore credentials rotate every 90 days." }
    document_title { document&.title || "Security Handbook" }
    heading_path { "Secrets › Rotation" }
  end
end
