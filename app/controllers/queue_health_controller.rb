class QueueHealthController < ActionController::API
  def show
    health = BackgroundJobs::QueueHealth.new

    if health.healthy?
      render json: { status: "ok" }
    else
      queues = health.problems.to_h { |problem| [problem.queue, problem.kind] }
      # Error, not warn: production silences this path below error.
      Rails.logger.error("Unhealthy job queues: #{queues}")
      render json: { status: "unhealthy", queues: }, status: :service_unavailable
    end
  end
end
