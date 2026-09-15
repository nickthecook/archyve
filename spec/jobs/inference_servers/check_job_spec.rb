require "rails_helper"

RSpec.describe InferenceServers::CheckJob do
  subject(:job) { described_class.new }

  let(:server) { create(:ollama_server, last_checked_at: nil) }

  describe "#perform" do
    context "when the server answers" do
      before { allow(server).to receive(:available_models).and_return([]) }

      it "records that it is reachable" do
        job.perform(server)
        expect(server.reload).to be_reachable
      end
    end

    context "when the server is unreachable" do
      before { allow(server).to receive(:available_models).and_raise(Faraday::ConnectionFailed, "refused") }

      # #check! swallows everything so it can record the reason. If that ever
      # stopped being true the job would retry a dead host on a schedule.
      it "doesn't raise" do
        expect { job.perform(server) }.not_to raise_error
      end

      it "records why" do
        job.perform(server)
        expect(server.reload.last_check_error).to include("refused")
      end
    end
  end
end
