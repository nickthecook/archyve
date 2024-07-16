module Api
  class ChatResponse
    def initialize(prompt, model: nil, api_client: nil, augment: false, collections: nil)
      @prompt = prompt
      @model = model
      @api_client = api_client
      @augment = augment
      @collections = collections

      @response = ""
    end

    def respond
      generate_response

      { reply: @response, augmented: @augment, statistics: client.clean_stats }
    end

    private

    def generate_response
      # TODO: get the response all at once instead of streaming
      if @augment
        augment_prompt
        client.complete(@augmented_prompt) { |text| @response << text }
      else
        client.complete(@prompt) { |text| @response << text }
      end
    end

    def augment_prompt
      @augmented_prompt = prompt_augmentor.prompt
    end

    def prompt_augmentor
      @prompt_augmentor ||= begin
        search_hits = searcher.search(@prompt)

        PromptAugmentor.new(@message, search_hits)
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
      @client ||= model_loader.client("ollama")
    end

    def model_loader
      @model_loader ||= ModelLoader.new(model: @model, traceable: @api_client)
    end
  end
end
