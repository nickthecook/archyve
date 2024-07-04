class CleanApiCallsJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    max_age = args.first || Setting.get("max_api_call_age_in_days") || 14
    oldest_creation_time = Time.zone.now - (max_age * 24 * 60 * 60)

    api_calls = ApiCall.where('created_at < ?', oldest_creation_time)
    Rails.logger.info "Cleaning #{api_calls.count} API calls created before #{oldest_creation_time}..."
    api_calls.delete_all
  end
end
