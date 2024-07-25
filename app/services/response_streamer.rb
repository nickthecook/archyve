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

  def initialize(model_config:, traceable: nil)
    @client_helper = Helpers::ModelClientHelper.new(model_config:, traceable:)
  end

  def complete(prompt, &)
    client.complete(prompt) do |response|
      handle(response, &)
    end
  end

  def chat(message, &)
    client.chat(message) do |response|
      handle(response, &) unless response.nil?
    end
  end

  private

  def client
    @client_helper.client
  end

  def handle(response)
    message, raw_message = processor.append(response)
    yield message, raw_message
  rescue Net::HTTPError => e
    raise NetworkError, "Error communicating with server: #{e.message}"
  rescue Errno::ECONNREFUSED => e
    raise NetworkError, "Connection refused: #{e.message}"
  end

  def processor
    @processor ||= MessageProcessor.new
  end
end
