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

  def initialize(model, prompt)
    @model = OpenStruct.new(model)
    @prompt = prompt
    @chunk = ""
  end

  def stream
    client.call(@prompt) do |response|
      @on_start&.call
      @on_start = nil

      message = processor.append(response)

      yield message
    rescue Net::HTTPError => e
      raise NetworkError, "Error communicating with server: #{e.message}"
    end

    @on_finish&.call
  end

  def on_start(&block)
    @on_start = block
  end

  def on_finish(&block)
    @on_finish = block
  end

  private

  def headers
    headers = { "Content-Type": "application/json" }

    headers[:Authorization] = "Bearer #{@model.api_key}" if @model.api_key

    headers
  end

  def processor
    @processor ||= MessageProcessor.new
  end

  def client
    @client ||= client_class_for(@model.provider).new(
      endpoint: @model.endpoint,
      api_key: @model.api_key,
      model: @model.model,
      batch_size: BATCH_SIZE
    )
  end

  def client_class_for(provider)
    klass = LlmClients.const_get(provider.camelize)

    raise UnsupportedServerError, "Only 'ollama' is supported. You asked for '#{provider}'." unless klass

    klass
  end
end
