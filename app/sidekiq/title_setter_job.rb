class TitleSetterJob
  include Sidekiq::Job

  def perform(*args)
    @conversation = Conversation.find(args.first)

    SetConversationTitle.new(@conversation).execute
  end
end
