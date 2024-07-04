RSpec.describe CleanApiCallsJob, type: :job do
  describe "#perform" do
    let(:time) { Time.zone.now }

    before do
      Timecop.freeze(time) do
        create(:api_call, created_at: 15.days.ago)
        create(:api_call, created_at: 14.days.ago)
        create(:api_call, created_at: 13.days.ago)
      end
    end

    it "deletes ApiCalls older than 14 days" do
      Timecop.freeze(time) do
        expect { subject.perform }.to change(ApiCall, :count).by(-1)
      end
    end

    it "accepts an arg to set the max days" do
      Timecop.freeze(time) do
        expect { subject.perform(13) }.to change(ApiCall, :count).by(-2)
      end
    end

    context "when Setting is set" do
      before do
        Setting.set("max_api_call_age_in_days", 13)
      end

      it "deletes ApiCalls older than 13 days" do
        Timecop.freeze(time) do
          expect { subject.perform }.to change(ApiCall, :count).by(-2)
        end
      end

      it "prefers an arg over the Setting" do
        Timecop.freeze(time) do
          expect { subject.perform(12) }.to change(ApiCall, :count).by(-3)
        end
      end
    end
  end
end
