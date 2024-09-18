unless ENV.include?("DEFAULT_CLIENT_ID") && ENV.include?("DEFAULT_API_KEY")
  raise StandardError, "To run end-to-end tests, please set DEFAULT_CLIENT_ID and DEFAULT_API_KEY"
end

require 'httparty'
require 'pry'

Dir.glob('spec/support/api/**/*.rb').each do |f|
  require "#{Dir.pwd}/#{f}"
end

def api_url
  ENV.fetch('API_URL', "http://localhost:3300")
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

def get(path)
  path = "/#{path}" unless path.start_with?('/')
  response = HTTParty.get("#{api_url}#{path}", headers:)

  Response.new(response.code, response.headers, response.body, JSON.parse(response.body))
end
