class SidekiqCronSchedule
  def initialize(default_jobs)
    @default_jobs = default_jobs
  end

  def load!
    # remove all existing jobs from redis - Sidekiq::Cron won't do this for us
    Sidekiq::Cron::Job.destroy_all!

    if jobs.any?
      Sidekiq.logger.info "Loading Sidekiq Cron jobs hash: #{jobs}"
      Sidekiq::Cron::Job.load_from_hash(jobs)
    else
      Sidekiq.logger.info "Not loading Sidekiq Cron, as 'SIDEKIQ_CRON' env var is not set."
    end
  end

  private

  def jobs
    @jobs ||= if ENV.fetch("CONFIGURE_DEFAULT_JOBS", nil) == "false"
      env_jobs
    else
      @default_jobs.deep_merge(env_jobs)
    end
  end

  def env_jobs
    @env_jobs ||= JSON.parse(sidekiq_config_string)
  rescue StandardError
    {}
  end

  def sidekiq_config_string
    @sidekiq_config_string ||= ENV.fetch('SIDEKIQ_CRON', nil)
  end
end
