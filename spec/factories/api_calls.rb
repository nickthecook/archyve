FactoryBot.define do
  factory :api_call do
    kind { "chat" }
    service_name { "ollama" }
    http_method { "POST" }
    url { "http://localhost:11434/api/chat" }
    request_headers { { "content-type" => "application/json" } }
    request_body { { "model" => "llama3.2", "stream" => true } }
    request_length { 420 }
    response_headers { { "content-type" => "application/json" } }
    response_body { { "message" => { "content" => "An answer." } } }
    response_length { 1024 }
    response_code { 200 }
    duration_ms { 1234 }

    # Nothing answered, which is most of what goes wrong with a self-hosted
    # server — see ApiCall::NO_RESPONSE.
    trait :refused do
      response_code { ApiCall::NO_RESPONSE[:connection_refused] }
      response_headers { nil }
      response_body { nil }
      response_length { nil }
      error { "Failed to open TCP connection to localhost:11434" }
    end
  end
end
