require "rails_helper"

RSpec.describe InferenceServers::EnqueueDueChecksJob do
  subject(:job) { described_class.new }

  let(:result) { job.perform }

  describe "#perform" do
    context "with a server that has never been checked" do
      let!(:server) { create(:ollama_server, last_checked_at: nil) }

      it "enqueues a probe for it" do
        expect { result }.to have_enqueued_job(InferenceServers::CheckJob).with(server)
      end
    end

    context "with a server checked longer ago than the interval" do
      let!(:server) { create(:ollama_server, last_checked_at: 2.hours.ago) }

      it "enqueues a probe for it" do
        expect { result }.to have_enqueued_job(InferenceServers::CheckJob).with(server)
      end
    end

    # Traffic is the check. Probing a server that chat or search is already
    # exercising buys nothing and costs a metered provider real money.
    context "with a server whose status is still fresh" do
      before { create(:ollama_server, last_checked_at: 1.minute.ago) }

      it "leaves it alone" do
        expect { result }.not_to have_enqueued_job(InferenceServers::CheckJob)
      end
    end

    # The only way an idle host that died ever goes green again.
    context "with a stale server that is currently failing" do
      let!(:server) do
        create(:ollama_server).tap do |s|
          s.update_columns(last_check_status: "failed", last_checked_at: 2.hours.ago)
        end
      end

      it "probes it anyway" do
        expect { result }.to have_enqueued_job(InferenceServers::CheckJob).with(server)
      end
    end

    context "with several due servers" do
      before do
        create(:ollama_server, last_checked_at: nil)
        create(:openai_server, last_checked_at: nil)
      end

      it "enqueues one probe each" do
        expect { result }.to have_enqueued_job(InferenceServers::CheckJob).twice
      end
    end
  end
end
