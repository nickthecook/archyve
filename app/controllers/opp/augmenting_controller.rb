module Opp
  class AugmentingController < StreamingController
    before_action :return_if_no_messages
    before_action :augment_prompt
    before_action :update_request

    def post
      formatted_response, raw_response = chat_response_formatter.execute do |chunk|
        response.stream.write(chunk)
      end

      response.stream.close

      MessageCreator.new(
        @message.conversation,
        @opp_request.model
      ).create!("assistant", formatted_response, raw_response)
    end

    protected

    def set_request
      @opp_request = ChatRequest.new(request)
    end

    private

    def chat_response_formatter
      @chat_response_formatter ||= ChatResponseFormatter.new(@proxy)
    end

    def return_if_no_messages
      head :no_content if @opp_request.messages_with_content.empty?
    end

    def augment_prompt
      # TODO: when authn is implemented, find User based on Client
      @message = ChatAugmentor.new(@opp_request, User.first).execute
    end

    def update_request
      return if @opp_request.messages_with_content.empty?

      @opp_request.last_user_message["content"] = @message.prompt
    end
  end
end
