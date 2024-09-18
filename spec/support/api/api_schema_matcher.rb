require 'json-schema'

class String
  def is_integer?
    true if Integer(self)
  rescue StandardError
    false
  end
end

def content_for_exception(data, path)
  attr = data

  path.each do |key|
    key = key.to_i if key.is_integer?

    attr = attr[key]
  end

  attr
end

RSpec::Matchers.define :match_response_schema do |schema|
  match do |response|
    schema_directory = "#{Dir.pwd}/spec/support/api/schemas"
    schema_path = "#{schema_directory}/#{schema}.json"

    JSON::Validator.validate!(schema_path, response.body, strict: true)
  rescue JSON::Schema::ValidationError => e
    puts e
    puts "Offending value: #{content_for_exception(response.parsed_body, e.fragments)}"
    raise RSpec::Expectations::ExpectationNotMetError, "Response does not match schema #{schema}: #{e}"
  end
end
