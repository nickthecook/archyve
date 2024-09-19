def chunk_hashes_from_response(body)
  body.lines.map do |l|
    l.gsub!(/^data: /, "")
    JSON.parse(l)
  rescue JSON::ParserError
    nil
  end.compact
end

def validate_chunk(schema, chunk)
  schema_directory = "#{Dir.pwd}/spec/support/api/schemas"
  schema_path = "#{schema_directory}/#{schema}.json"

  JSON::Validator.validate!(schema_path, chunk, strict: true)
rescue JSON::Schema::ValidationError => e
  puts e
  puts "Offending value: #{content_for_exception(chunk, e.fragments)}"
  raise RSpec::Expectations::ExpectationNotMetError, "Response does not match schema #{schema}: #{e}"
end

RSpec::Matchers.define :have_chunks_matching_schema do |schema, last_chunk_schema|
  match do |response|
    body = response.body
    chunks = chunk_hashes_from_response(body)
    last_chunk = chunks.pop
    last_chunk_schema ||= schema

    chunks.each { |chunk| validate_chunk(schema, chunk) }
    validate_chunk(last_chunk_schema, last_chunk)
  end
end
