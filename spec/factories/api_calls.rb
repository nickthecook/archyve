FactoryBot.define do
  factory :api_call do
    service_name { "mr_sparkle" }
    http_method { :get }
    url { "http://localhost:9999/api/generate" }
    headers { { "Content-Type": "application/json" } }
    body { nil }
    body_length { nil }
    response_code { 200 }
    response_body { { success: true, message: "Success!" }.to_json }
    traceable { nil }
  end
end
