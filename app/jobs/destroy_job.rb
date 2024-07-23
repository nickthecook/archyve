class DestroyJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    document = Document.find(args.first)

    TheDestroyor.new(document).destroy
  end
end
