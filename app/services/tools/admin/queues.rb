# frozen_string_literal: true

module Tools
  module Admin
    class Queues < Base
      def name = "check_queues"
      def label = "the job queues"

      def description
        "Check the background job queues: what is waiting, running, scheduled and failed on each, which " \
          "workers are alive and which queues they take, and any queue that no worker is taking work from."
      end

      def execute(**)
        {
          status: "ok",
          problems: health.problems.map { "#{it.queue}: #{problem_text(it.kind)}" }.join("; ").presence || "none",
          queues: queues.presence || "none have any jobs",
          paused: SolidQueue::Pause.pluck(:queue_name).join(", ").presence || "none",
          workers: workers.presence || "none registered"
        }
      end

      private

      def health = BackgroundJobs::QueueHealth.new

      def queues
        ready = SolidQueue::ReadyExecution.group(:queue_name).count
        scheduled = SolidQueue::ScheduledExecution.group(:queue_name).count
        claimed = per_queue(SolidQueue::ClaimedExecution)
        failed = per_queue(SolidQueue::FailedExecution)

        (ready.keys | scheduled.keys | claimed.keys | failed.keys).sort.map do |queue|
          { queue:, waiting: ready[queue].to_i, running: claimed[queue].to_i,
            scheduled: scheduled[queue].to_i, failed: failed[queue].to_i }
        end
      end

      def per_queue(executions)
        executions.joins(:job).group("solid_queue_jobs.queue_name").count
      end

      def workers
        SolidQueue::Process.where(kind: "Worker").order(:name).map do |worker|
          { name: worker.name, queues: worker.metadata["queues"], threads: worker.metadata["pool_size"],
            last_heartbeat: worker.last_heartbeat_at.iso8601,
            alive: worker.last_heartbeat_at > SolidQueue.process_alive_threshold.ago }
        end
      end

      def problem_text(kind)
        case kind
        when :uncovered then "work is waiting and no live worker takes this queue"
        when :stalled then "work has waited a while, a worker covers it with idle threads, and nothing has moved"
        end
      end
    end
  end
end
