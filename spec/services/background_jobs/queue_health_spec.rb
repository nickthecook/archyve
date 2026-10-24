require "rails_helper"

RSpec.describe BackgroundJobs::QueueHealth do
  subject(:health) { described_class.new }

  let(:worker_queues) { "default,ingestion" }
  let(:heartbeat) { Time.current }
  let(:pool_size) { 2 }
  let(:claimed) { 0 }
  let(:waiting) { { "default" => 1.second } }
  let(:paused) { [] }
  let(:progress) { nil }
  let(:progress_at) { 1.minute.ago }

  let!(:worker) do
    SolidQueue::Process.create!(
      kind: "Worker", name: "worker-#{SecureRandom.hex(4)}", pid: 1, hostname: "spec",
      last_heartbeat_at: heartbeat, metadata: { queues: worker_queues, pool_size: }
    )
  end

  before do
    waiting.each do |queue, waited|
      SolidQueue::Job.create!(class_name: "ApplicationJob", queue_name: queue)
        .ready_execution.update!(created_at: waited.ago)
    end

    claimed.times do
      job = SolidQueue::Job.create!(class_name: "ApplicationJob", queue_name: "busy", scheduled_at: 1.hour.from_now)
      SolidQueue::ClaimedExecution.create!(job:, process: worker)
    end

    paused.each { |queue| SolidQueue::Pause.create!(queue_name: queue) }

    if progress
      job = SolidQueue::Job.create!(class_name: "ApplicationJob", queue_name: "default", scheduled_at: 1.hour.from_now)
      case progress
      when :finished then job.update!(finished_at: progress_at)
      when :claimed then SolidQueue::ClaimedExecution.create!(job:, process: worker, created_at: progress_at)
      when :failed then SolidQueue::FailedExecution.create!(job:, error: {}, created_at: progress_at)
      end
    end
  end

  describe "#problems" do
    let(:result) { health.problems.map { |problem| [problem.queue, problem.kind] } }

    it { expect(result).to be_empty }

    context "with nothing waiting" do
      let(:waiting) { {} }
      let(:worker_queues) { "docling" }

      it { expect(result).to be_empty }
    end

    context "when the worker covers other queues" do
      let(:worker_queues) { "docling" }

      it { expect(result).to eq([["default", :uncovered]]) }

      context "with the queue paused" do
        let(:paused) { ["default"] }

        it { expect(result).to be_empty }
      end
    end

    context "when the worker's heartbeat has lapsed" do
      let(:heartbeat) { SolidQueue.process_alive_threshold.ago - 1.minute }

      it { expect(result).to eq([["default", :uncovered]]) }
    end

    context "when the worker polls every queue" do
      let(:worker_queues) { "*" }

      it { expect(result).to be_empty }
    end

    context "when the worker polls by prefix" do
      let(:worker_queues) { "def*" }

      it { expect(result).to be_empty }
    end

    context "with work waiting past the stall threshold" do
      let(:waiting) { { "default" => described_class::STALL_AFTER + 1.minute } }

      it { expect(result).to eq([["default", :stalled]]) }

      context "when every worker thread is busy" do
        let(:claimed) { pool_size }

        it { expect(result).to be_empty }
      end

      context "when a job on the queue finished recently" do
        let(:progress) { :finished }

        it { expect(result).to be_empty }

        context "but before the stall threshold" do
          let(:progress_at) { described_class::STALL_AFTER.ago - 1.minute }

          it { expect(result).to eq([["default", :stalled]]) }
        end
      end

      context "when a job on the queue started recently" do
        let(:progress) { :claimed }

        it { expect(result).to be_empty }
      end

      context "when a job on the queue failed recently" do
        let(:progress) { :failed }

        it { expect(result).to be_empty }
      end
    end
  end

  describe "#healthy?" do
    let(:result) { health.healthy? }

    it { expect(result).to be(true) }

    context "with an uncovered queue" do
      let(:worker_queues) { "docling" }

      it { expect(result).to be(false) }
    end
  end
end
