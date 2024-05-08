class TitleSetterJob
  include Sidekiq::Job

  sidekiq_options retry: 1

  def perform(*args)
    @conversation = Conversation.find(args.first)

    SetConversationTitle.new(@conversation).execute
  end
end
