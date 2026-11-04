FactoryBot.define do
  factory :conversation do
    association :user
    agent { Agent.archivist }
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

  factory :feedback do
    association :message
    rating { nil }
    comment { nil }
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

    factory :reading_segment do
      kind { "reading" }
      content { nil }
      reading do
        { "document_id" => 1, "title" => "Security Handbook",
          "from" => 10, "to" => 14, "total" => 47 }
      end
    end

    factory :listing_segment do
      kind { "listing" }
      content { nil }
      listing do
        { "kind" => "collections", "from" => 1, "to" => 2, "total" => 2,
          "entries" => [
            { "name" => "Security Handbook", "slug" => "security-handbook",
              "documents" => 12, "sources" => ["Wiki"] },
            { "name" => "Runbooks", "slug" => "runbooks", "documents" => 3, "sources" => [] }
          ] }
      end

      trait :documents do
        listing do
          { "kind" => "documents", "title" => "Security Handbook",
            "from" => 1, "to" => 2, "total" => 9,
            "entries" => [
              { "id" => 41, "title" => "Credential rotation", "source" => "Wiki", "chunks" => 14 },
              { "id" => 42, "title" => "Bastion access", "source" => "Wiki", "chunks" => 0 }
            ] }
        end
      end

      trait :refused do
        listing { { "kind" => "documents", "refusal" => "not_found" } }
      end
    end
  end

  factory :hit do
    association :segment, factory: :retrieval_segment
    association :chunk
    document { chunk.document }
    handle { 1 }
    distance { 0.2 }
    score { 0.016 }
    position { chunk&.position }
    snippet { "Production datastore credentials rotate every 90 days." }
    document_title { document&.title || "Security Handbook" }
    heading_path { "Secrets › Rotation" }

    # A chunk the model read rather than found: nothing ranked it.
    trait :read do
      association :segment, factory: :reading_segment
      distance { nil }
      score { nil }
    end
  end
end
