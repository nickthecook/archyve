require_relative "common"

# rubocop:disable all
module LlmClients
  class Openai < Client
    def call(prompt)
      @stats = new_stats
      request = request(prompt)

      Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https") do |http|
        http.request(request) do |response|
          raise response_error_for(response) unless response.code.to_i >= 200 && response.code.to_i < 300

          stats[:start_time] = current_time
          stats[:first_token_time] = current_time
          body = response.read_body
          content = ""
          each_message(body) do |message|
            @stats[:tokens] += 1
            content += message if message
          end

          yield content

          calculate_stats
        end
      end
    end

    private

    def each_message(response_string)
      response_string.scan(/^data: ({.*})$/).each do |match|
        yield extract_message(match.first)
      end
    end

    def extract_message(response_string)
      response_hash = JSON.parse(response_string)
      message = response_hash["choices"].first["delta"]["content"]
      Rails.logger.info("<== '#{message}'")

      message
    end

    def request(prompt)
      request = Net::HTTP::Post.new(@uri, **headers)
      request.body = {
        model: @model,
        messages: [
          {
            role: "system",
            content: "You are an assistant that answers questions based on context extracted from documents."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        stream: true
      }.to_json

      request
    end

    def context(prompt, model)
      template = template_for(model)

      "#{template[:prefix]}#{prompt}#{template[:suffix]}"
    end

    def completion_path
      "chat/completions"
    end
  end
end
# rubocop:enable All
