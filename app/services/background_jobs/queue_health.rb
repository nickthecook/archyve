module BackgroundJobs
  # Ready work no live worker will take, read from Solid Queue's own tables.
  # A queue nobody polls looks exactly like an empty one from inside the app.
  class QueueHealth
    STALL_AFTER = 5.minutes

    Problem = Data.define(:queue, :kind)

    def initialize(stall_after: STALL_AFTER)
      @stall_after = stall_after
    end

    def healthy? = problems.empty?

    def problems
      @problems ||= waiting.filter_map do |queue, oldest|
        covering = live_workers.select { |worker| covered_queues(worker).include?(queue) }

        if covering.empty?
          Problem.new(queue:, kind: :uncovered)
        elsif oldest < @stall_after.ago && !progressed?(queue) && covering.any? { |worker| idle_threads?(worker) }
          Problem.new(queue:, kind: :stalled)
        end
      end
    end

    private

    def waiting
      SolidQueue::ReadyExecution
        .where.not(queue_name: SolidQueue::Pause.select(:queue_name))
        .group(:queue_name)
        .minimum(:created_at)
    end

    def live_workers
      @live_workers ||= SolidQueue::Process
        .where(kind: "Worker", last_heartbeat_at: SolidQueue.process_alive_threshold.ago..)
        .to_a
    end

    def covered_queues(worker)
      @covered_queues ||= {}
      @covered_queues[worker.id] ||= SolidQueue::QueueSelector
        .new(worker.metadata["queues"]&.split(","), SolidQueue::ReadyExecution)
        .scoped_relations
        .flat_map { |relation| relation.distinct.pluck(:queue_name) }
    end

    # Finished jobs are only visible while SolidQueue.preserve_finished_jobs is on (the default).
    def progressed?(queue)
      since = @stall_after.ago
      on_queue = { solid_queue_jobs: { queue_name: queue } }

      SolidQueue::Job.where(queue_name: queue, finished_at: since..).exists? ||
        SolidQueue::ClaimedExecution.joins(:job).where(on_queue).where(created_at: since..).exists? ||
        SolidQueue::FailedExecution.joins(:job).where(on_queue).where(created_at: since..).exists?
    end

    # A queue whose threads are all held by long jobs is a backlog, not a stall.
    def idle_threads?(worker)
      SolidQueue::ClaimedExecution.where(process_id: worker.id).count < worker.metadata["pool_size"].to_i
    end
  end
end
