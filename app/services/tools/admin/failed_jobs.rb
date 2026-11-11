# frozen_string_literal: true

module Tools
  module Admin
    class FailedJobs < Base
      ARGUMENTS_LIMIT = 300
      BACKTRACE_LINES = 5

      parameters do
        integer :limit, description: "How many of the most recent failures to show, up to #{MAX_LIMIT}. Defaults to 10.",
          required: false
      end

      def name = "list_failed_jobs"
      def label = "failed jobs"

      def description
        "List the most recent background jobs that failed, newest first, with the error each raised " \
          "and the first lines of its backtrace."
      end

      def execute(limit: nil)
        failures = SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(capped(limit, default: 10))

        {
          status: "ok",
          total_failed: SolidQueue::FailedExecution.count,
          failures: failures.map { entry(it) }.presence || "none"
        }
      end

      private

      def entry(failure)
        job = failure.job
        {
          job_id: job.id, job: job.class_name, queue: job.queue_name, failed_at: failure.created_at.iso8601,
          error: "#{failure.exception_class}: #{failure.message}",
          backtrace: Rails.backtrace_cleaner.clean(Array(failure.backtrace)).first(BACKTRACE_LINES).join(" | "),
          arguments: Array(job.arguments&.dig("arguments")).to_json.truncate(ARGUMENTS_LIMIT)
        }
      end
    end
  end
end
