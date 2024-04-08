class DestroyJob
  include Sidekiq::Job

  def perform(*args)
    document = Document.find(args.first)

    TheDestroyor.new(document).destroy
  end
end
