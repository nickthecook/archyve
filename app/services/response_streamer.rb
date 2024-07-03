require "delegate"

require_relative "message_processor"

class ResponseStreamer
  class ResponseStreamerError < StandardError; end
  class NetworkError < ResponseStreamerError; end
  class UnsupportedServerError < ResponseStreamerError; end

  delegate :input, to: :processor
  delegate :output, to: :processor
  delegate :stats, to: :client

  BATCH_SIZE = 16

  def initialize(endpoint:, model:, provider:, api_key: nil, traceable: nil)
    @endpoint = endpoint
    @model = model
    @provider = provider
    @api_key = api_key
    @traceable = traceable

    @chunk = ""
  end

  def complete(prompt, &)
    client.complete(prompt) do |response|
      handle(response, &)
    end
  end

  def chat(chat, &)
    client.chat(chat) do |response|
      handle(response, &)
    end
  end

  private

  def handle(response)
    message = processor.append(response)

    yield message
  rescue Net::HTTPError => e
    raise NetworkError, "Error communicating with server: #{e.message}"
  rescue Errno::ECONNREFUSED => e
    raise NetworkError, "Connection refused: #{e.message}"
  end

  def headers
    headers = { "Content-Type": "application/json" }

    headers[:Authorization] = "Bearer #{@api_key}" if @api_key

    headers
  end

  def processor
    @processor ||= MessageProcessor.new
  end

  def client
    @client ||= LlmClients::Client.client_class_for(@provider).new(
      endpoint: @endpoint,
      api_key: @api_key,
      model: @model,
      batch_size: BATCH_SIZE,
      traceable: @traceable
    )
  end
end
