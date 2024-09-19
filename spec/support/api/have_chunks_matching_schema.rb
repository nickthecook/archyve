def chunk_hashes_from_response(body)
  body.lines.map do |l|
    l.gsub!(/^data: /, "")
    JSON.parse(l)
  rescue JSON::ParserError
    nil
  end.compact
end

RSpec::Matchers.define :have_chunks_matching_schema do |schema|
  match do |response|
    schema_directory = "#{Dir.pwd}/spec/support/api/schemas"
    schema_path = "#{schema_directory}/#{schema}.json"
    body = response.body
    chunks = chunk_hashes_from_response(body)

    chunks.each do |chunk|
      JSON::Validator.validate!(schema_path, chunk, strict: true)
    rescue JSON::Schema::ValidationError => e
      puts e
      puts "Offending value: #{content_for_exception(chunk, e.fragments)}"
      raise RSpec::Expectations::ExpectationNotMetError, "Response does not match schema #{schema}: #{e}"
    end
  end
end
