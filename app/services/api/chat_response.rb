module Api
  class ChatResponse
    TITLE_LENGTH = 120

    attr_reader :reply

    def initialize(prompt, model: nil, api_client: nil, augment: false, collections: nil)
      @prompt = prompt
      @model = model
      @api_client = api_client
      @augment = augment
      @collections = collections
    end

    def respond
      response

      Message.create!(content: response, conversation:, author: @api_client.user, statistics: client.stats)

      { reply: response, augmented: @augment, statistics: client.clean_stats }
    end

    private

    def response
      # TODO: get the response all at once instead of streaming
      @response ||= if @augment
        prompt_augmentor.augment

        client.complete(prompt_augmentor.prompt)
      else
        client.complete(@prompt)
      end
    end

    def prompt_augmentor
      @prompt_augmentor ||= begin
        search_hits = searcher.search(@prompt)

        PromptAugmentor.new(message, search_hits)
      end
    end

    def searcher
      @searcher ||= Search::SearchN.new(
        @collections || Collection.all,
        num_results: Setting.get(:num_chunks_to_include),
        traceable: @api_client
      )
    end

    def client
      @client ||= model_loader.client
    end

    def model_loader
      @model_loader ||= ModelLoader.new(model: @model, traceable: @api_client)
    end

    def message
      @message ||= Message.create!(
        content: @prompt,
        conversation:,
        author: @api_client.user
      )
    end

    def conversation
      @conversation ||= Conversation.create!(
        user: @api_client.user,
        title: @prompt.truncate(TITLE_LENGTH),
        model_config: model_loader.model_config,
        search_collections: @augment
      )
    end
  end
end
