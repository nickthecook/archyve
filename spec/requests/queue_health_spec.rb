require "rails_helper"

RSpec.describe "Queue health check", :unauthenticated, type: :request do
  subject(:request) { get queue_health_check_path }

  let(:worker_queues) { "default" }

  before do
    SolidQueue::Process.create!(
      kind: "Worker", name: "worker-spec", pid: 1, hostname: "spec",
      last_heartbeat_at: Time.current, metadata: { queues: worker_queues, pool_size: 1 }
    )
    SolidQueue::Job.create!(class_name: "ApplicationJob", queue_name: "default")
    request
  end

  it { expect(response).to have_http_status(:ok) }
  it { expect(response.parsed_body).to eq("status" => "ok") }

  context "with a queue no worker covers" do
    let(:worker_queues) { "docling" }

    it { expect(response).to have_http_status(:service_unavailable) }
    it { expect(response.parsed_body).to eq("status" => "unhealthy", "queues" => { "default" => "uncovered" }) }
  end
end
