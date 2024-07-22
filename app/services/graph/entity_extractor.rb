module Graph
  class EntityExtractor
    def initialize(model_config, traceable: nil)
      @model_config = model_config
      @traceable = traceable
      @prompt_template = ERB.new(Graph::ENTITY_EXTRACTION_PROMPT)
    end

    def extract(chunk)
      entities_for(chunk).each_line do |line|
        break if line =~ /########/

        response = EntityExtractionResponse.new(line)

        if response.entity?
          response_values = response.to_h
          entity = Entity.find_or_create_by!(entity_type: response_values[:subtype], name: response_values[:name])
          EntityDescription.create!(entity:, description: response_values[:desc])
        elsif response.relationship?
          puts "LATER!"
        else
          Rails.logger.warn("Unable to extract entity or relationship: #{line}")
        end
      end
    end

    private

    def entities_for(chunk)
      client.complete(prompt_for(chunk.content))
    end

    def client
      @client ||= LlmClients::Client.client_class_for(active_server.provider).new(
        endpoint: active_server.url,
        model: @model_config.model,
        api_key: "todo",
        traceable: @traceable
      )
    end

    def active_server
      @active_server ||= ModelServer.active_server
    end

    def prompt_for(input_text)
      @prompt_template.result(binding)
    end

    ###
    # template values
    def tuple_delimiter
      "|"
    end

    def record_delimiter
      "##"
    end

    def completion_delimiter
      "|COMPLETE|"
    end

    def entity_types
      %w[organization person geo event]
    end

    def input_text
      @chunk.content
    end
  end
end
