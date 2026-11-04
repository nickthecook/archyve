require "rails_helper"

RSpec.describe Tools::Admin::Queues do
  subject(:tool) { described_class.new }

  describe "#execute" do
    let(:result) { tool.execute }
    let(:worker_queues) { "default" }

    before do
      SolidQueue::Process.create!(
        kind: "Worker", name: "worker-1", pid: 1, hostname: "spec",
        last_heartbeat_at: Time.current, metadata: { queues: worker_queues, pool_size: 2 }
      )
      SolidQueue::Job.create!(class_name: "ApplicationJob", queue_name: "ingestion")
    end

    it "counts what is waiting on each queue" do
      expect(result[:queues]).to include(queue: "ingestion", waiting: 1, running: 0, scheduled: 0, failed: 0)
    end

    it "names the workers and what they take" do
      expect(result[:workers].first).to include(name: "worker-1", queues: "default", alive: true)
    end

    context "when no worker takes a queue with work on it" do
      it "says so" do
        expect(result[:problems]).to eq("ingestion: work is waiting and no live worker takes this queue")
      end
    end

    context "when every queue is covered" do
      let(:worker_queues) { "default,ingestion" }

      it "reports no problems" do
        expect(result[:problems]).to eq("none")
      end
    end
  end
end
