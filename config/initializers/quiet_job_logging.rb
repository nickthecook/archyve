# frozen_string_literal: true

# ActiveJob::LogSubscriber isn't loaded by the time initializers run, unlike
# ActiveRecord's.
require "active_job/log_subscriber"

# Solid Cable calls `TrimJob.perform_now` on *every* broadcast, then rolls dice
# inside the job: trim_batch_size 100 against trim_chance 2 means it actually
# deletes something roughly 2% of the time. Streaming a chat response broadcasts
# per token flush, so the log fills with a job starting and finishing having
# done nothing — four tagged lines each, between every line worth reading.
#
# Trimming still happens; we just stop narrating the 98% that doesn't. Failures
# still log: ActiveJob reports those through the error subscriber and the
# exception propagates, neither of which routes through these methods.
module QuietJobLogging
  NOISY_JOBS = %w[SolidCable::TrimJob].freeze

  # Every ActiveJob::LogSubscriber event carrying a single job in its payload.
  # `enqueue_all` is deliberately absent — it carries :jobs, and nothing we
  # silence uses the bulk path.
  EVENTS = %i[
    enqueue enqueue_at perform_start perform enqueue_retry retry_stopped discard
  ].freeze

  EVENTS.each do |event_name|
    define_method(event_name) do |event|
      job = event.payload[:job]
      next if job && NOISY_JOBS.include?(job.class.name)

      super(event)
    end
  end
end

ActiveJob::LogSubscriber.prepend(QuietJobLogging)

# Prepending puts a frame from this file on the stack above the real enqueue
# site, and `verbose_enqueue_logs` reports the first *unsilenced* frame — so
# without this every job's "↳ enqueued from" would point here instead of at the
# app code that enqueued it.
#
# This has to run inside on_load(:active_job): the ActiveJob railtie assigns
# `LogSubscriber.backtrace_cleaner = Rails.backtrace_cleaner` from its own
# hook, so a silencer added before ActiveJob::Base loads is attached to an
# object that then gets thrown away. Ours registers after the railtie's and so
# lands on the cleaner that survives. That cleaner strips the Rails.root prefix
# before silencers see a line, hence matching the basename, not __FILE__.
ActiveSupport.on_load(:active_job) do
  ActiveJob::LogSubscriber.backtrace_cleaner.add_silencer do |line|
    line.include?("quiet_job_logging.rb")
  end
end
