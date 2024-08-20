module Graph
  class EntityExtractor
    def initialize(model_config)
      @model_config = model_config
      @prompt_template = ERB.new(Graph::Prompts::ENTITY_EXTRACTION_PROMPT)
    end

    def extract(chunk)
      if chunk.content.size < minimum_chunk_size
        Rails.logger.info(
          "Chunk #{chunk.id} is too small to extract entities (#{chunk.content.size} < #{minimum_chunk_size})"
        )
        return
      end

      chunk.graph_entity_descriptions.destroy_all

      extract_chunk_entities(chunk)
    end

    private

    def extract_chunk_entities(chunk)
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

    def handle_entity(values, chunk)
      unless entity_types.include?(values[:subtype])
        Rails.logger.warn("Unrecognized entity type: #{values[:subtype]}")
        return
      end

      entity = GraphEntity.find_or_create_by!(
        entity_type: values[:subtype],
        name: values[:name],
        collection: chunk.collection
      )
      GraphEntityDescription.create!(graph_entity: entity, description: values[:desc], chunk:)
      entity.update!(summary_outdated: true)
    end

    def handle_relationship(values, chunk)
      from = GraphEntity.find_by(name: values[:from], collection: chunk.collection)
      to = GraphEntity.find_by(name: values[:to], collection: chunk.collection)

      unless from && to
        Rails.logger.warn("Unable to find entities: #{values[:from]} (#{from}) and/or #{values[:to]} (#{to})")
        return
      end

      GraphRelationship.find_or_create_by!(
        from_entity: from,
        to_entity: to,
        strength: values[:strength],
        description: values[:desc],
        chunk:
      )
    end

    def entities_for(chunk)
      entities = client.complete(prompt_for(chunk.content), traceable: chunk)

      Rails.logger.debug { "Extracted entities:\n#{entities}" }

      entities
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
      prompt = @prompt_template.result(binding)
      Rails.logger.info("Sending completion request:\n#{prompt}")

      prompt
    end

    ###
    # template values
    def tuple_delimiter
      " | "
    end

    def record_delimiter
      "##"
    end

    def completion_delimiter
      "|COMPLETE|"
    end

    def entity_types
      %w[organization person event concept technology mission location role project].join(" ")
    end

    def input_text
      @chunk.content
    end

    def minimum_chunk_size
      @minimum_chunk_size ||= Setting.get("minimum_chunk_size_for_extraction", default: 128)
    end
  end
end
