unless ENV.include?("DEFAULT_CLIENT_ID") && ENV.include?("DEFAULT_API_KEY")
  raise StandardError, "To run end-to-end tests, please set DEFAULT_CLIENT_ID and DEFAULT_API_KEY"
end

RSpec.configure do |config|
  # some specs do a thing in one example and then check its result in the next example
  config.order = :defined
end

require 'httparty'
require 'pry'

Dir.glob('spec/support/api/**/*.rb').each do |f|
  require "#{Dir.pwd}/#{f}"
end

def api_url
  ENV.fetch('API_URL', "http://localhost:3300")
end

def opp_url
  ENV.fetch('OPP_URL', "http://localhost:11337")
end

def headers
  {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json',
    'X-Client-Id' => ENV.fetch('DEFAULT_CLIENT_ID', nil),
    'Authorization' => "Bearer #{ENV.fetch('DEFAULT_API_KEY', nil)}",
  }
end

Response = Struct.new(:code, :headers, :body, :parsed_body)

def parse(json_str)
  JSON.parse(json_str)
rescue JSON::ParserError
  nil
end

def get(path, endpoint = api_url)
  path = "/#{path}" unless path.start_with?('/')
  response = HTTParty.get("#{endpoint}#{path}", headers:)

  Response.new(response.code, response.headers, response.body, parse(response.body))
end

def post(path, payload, endpoint = api_url)
  payload = payload.to_json unless payload.is_a?(String)

  response = HTTParty.post("#{endpoint}#{path}", headers:, body: payload)

  Response.new(response.code, response.headers, response.body, parse(response.body))
end

# rubocop:disable Rails/HttpPositionalArguments
def api_get(path)
  get(path, api_url)
end

def opp_get(path)
  get(path, opp_url)
end

def opp_post(path, payload)
  post(path, payload, opp_url)
end
# rubocop:enable Rails/HttpPositionalArguments

def test_collection_id
  @test_collection_id ||= begin
    collections = api_get("/v1/collections").parsed_body["collections"]
    raise StandardError, "No collections found!" if collections.empty?

    test_collection = collections.find { |c| c['name'] == 'Testing' }
    raise StandardError, "No collection found with name 'Testing'," unless test_collection

    test_collection_id = test_collection["id"]
    raise StandardError, "Could not get 'id' from test collection: #{test_collection}" if test_collection_id.nil?

    test_collection_id
  end
end
