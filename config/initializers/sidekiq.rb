# frozen_string_literal: true

require 'sidekiq/web'
Sidekiq::Web.app_url = "/"
Sidekiq.strict_args!(false)

require_relative '../../lib/sidekiq_cron_schedule'

# in test env, don't send anything to sidekiq
if Rails.env.test?
  require 'sidekiq/testing'
  Sidekiq::Testing.fake!
end

if Rails.configuration.run_sidekiq
  # if we're running sidekiq, set up `Rails.logger` so it still works
  Rails.application.reloader.to_prepare do
    Rails.logger = Sidekiq.logger
    ActiveRecord::Base.logger = Sidekiq.logger
  end

  # SCHEDULED JOBS
  #
  # These default_jobs will be scheduled on startup, unless CONFIGURE_DEFAULT_JOBS is set to false.
  # Jobs defined in SIDEKIQ_CRON will override the default jobs if they have the same name.
  # Even if CONFIGURE_DEFAULT_JOBS is false, you can still schedule jobs via SIDEKIQ_CRON.
  default_jobs = {
    "clean_api_calls" => {
      "cron" => "0 12 * * *",
      "class" => "CleanApiCallsJob",
      "args" => [],
      "description" => "Remove ApiCalls older than 14 days from the database",
      "status" => "enabled",
    },
  }

  Rails.application.reloader.to_prepare do
    SidekiqCronSchedule.new(default_jobs).load!
  end
end
