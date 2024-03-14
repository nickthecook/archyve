class ResponderJob
  include Sidekiq::Job

  def perform(*args)
    @message = Message.find(args.first)

    RespondToMessage.new(@message).execute
  end
end
