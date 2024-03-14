class ReplyJob
  include Sidekiq::Job

  def perform(*args)
    @message = Message.find(args.first)

    # TODO: this is a hack to keep the reply after the message to which it's a reply
    sleep(0.1)
    ReplyToMessage.new(@message).execute
  end
end
