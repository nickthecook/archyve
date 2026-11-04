require "rails_helper"

RSpec.describe Tools::Admin::FailedJobs do
  subject(:tool) { described_class.new(observer:) }

  let(:observer) { nil }

  def fail_job(class_name, message, at: Time.current)
    job = SolidQueue::Job.create!(class_name:, queue_name: "ingestion", arguments: { "arguments" => [42] },
      scheduled_at: 1.hour.from_now)
    SolidQueue::FailedExecution.create!(
      job:, created_at: at,
      error: {
        exception_class: "Docling::Unreachable", message:,
        backtrace: ["#{Rails.root}/app/jobs/parse_job.rb:12", "/gems/activejob/lib/active_job/execution.rb:68"]
      }
    )
  end

  describe "#execute" do
    let(:result) { tool.execute(**args) }
    let(:args) { {} }

    context "with nothing failed" do
      it { expect(result[:failures]).to eq("none") }
    end

    context "with failures" do
      before do
        fail_job("Ingestion::ParseJob", "older", at: 1.hour.ago)
        fail_job("Ingestion::EmbedJob", "connection refused")
      end

      it "puts the newest first" do
        expect(result[:failures].first).to include(job: "Ingestion::EmbedJob")
      end

      it "says what each raised" do
        expect(result[:failures].first[:error]).to eq("Docling::Unreachable: connection refused")
      end

      it "gives the app's own frames, relative to the app" do
        expect(result[:failures].first[:backtrace]).to eq("app/jobs/parse_job.rb:12")
      end

      it "counts every failure" do
        expect(result[:total_failed]).to eq(2)
      end
    end

    context "with a limit" do
      let(:args) { { limit: 1 } }

      before { 3.times { fail_job("Ingestion::ParseJob", "boom") } }

      it "shows only that many" do
        expect(result[:failures].size).to eq(1)
      end
    end
  end

  describe "#call" do
    let(:observer) { instance_double(Chat::Turn, tool_started: nil, tool_finished: nil) }
    let(:result) { tool.call({}) }

    it "tells the turn what it is checking" do
      result
      expect(observer).to have_received(:tool_started).with("list_failed_jobs", "failed jobs")
    end

    it "hands the turn the text the model reads" do
      result
      expect(observer).to have_received(:tool_finished).with(result)
    end

    context "when its budget is spent" do
      before { Tools::Admin::Base::MAX_ROUNDS.times { tool.call({}) } }

      it "refuses" do
        expect(result).to include("budget_spent")
      end
    end
  end
end
