module Opp
  class AugmentingController < StreamingController
    before_action :return_if_no_messages
    before_action :augment_prompt
    before_action :update_request

    protected

    def set_request
      @opp_request = ChatRequest.new(request)
    end

    private

    def return_if_no_messages
      head :no_content if @opp_request.messages_with_content.empty?
    end

    def augment_prompt
      # TODO: when authn is implemented, find user based on Client
      @message = ChatAugmentor.new(@opp_request, User.first).execute
    end

    def update_request
      return if @opp_request.messages_with_content.empty?

      @opp_request.last_user_message["content"] = @message.prompt
    end
  end
end
