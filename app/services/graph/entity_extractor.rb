module Graph
  class EntityExtractor
    def initialize(model_config, traceable: nil)
      @model_config = model_config
      @traceable = traceable
      @prompt_template = ERB.new(Graph::ENTITY_EXTRACTION_PROMPT)
    end

    def extract(chunk)
      chunk.entity_descriptions.destroy_all

      entities_for(chunk).each_line do |line|
        break if line =~ /########/

        response = EntityExtractionResponse.new(line)

        if response.entity?
          handle_entity(response.to_h, chunk)
        elsif response.relationship?
          handle_relationship(response.to_h, chunk)
        else
          Rails.logger.warn("Unable to extract entity or relationship: #{line}")
        end
      end
    end

    private

    def handle_entity(values, chunk)
      unless entity_types.include?(values[:subtype])
        Rails.logger.warn("Unrecognized entity type: #{values[:subtype]}")
        return
      end

      entity = Entity.find_or_create_by!(
        entity_type: values[:subtype],
        name: values[:name],
        collection: chunk.collection
      )
      EntityDescription.create!(entity:, description: values[:desc], chunk:)
      entity.update!(summary_outdated: true)
    end

    def handle_relationship(values, chunk)
      from = Entity.find_by(name: values[:from], collection: chunk.collection)
      to = Entity.find_by(name: values[:to], collection: chunk.collection)

      unless from && to
        Rails.logger.warn("Unable to find entities: #{values[:from]} (#{from}) and/or #{values[:to]} (#{to})")
        return
      end

      Relationship.find_or_create_by!(from:, to:, strength: values[:strength], description: values[:desc], chunk:)
    end

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
      %w[organization person event concept technology mission location role project]
    end

    def input_text
      @chunk.content
    end
  end
end
