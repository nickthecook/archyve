require "rails_helper"

RSpec.describe Sessions::SweepExpiredJob do
  describe "#perform" do
    let(:user) { create(:user) }
    let!(:expired) { user.sessions.create!(created_at: (Session::LIFETIME + 1.minute).ago) }
    let!(:active) { user.sessions.create!(created_at: 1.minute.ago) }

    it "deletes sessions past their lifetime" do
      described_class.perform_now

      expect(Session.exists?(expired.id)).to be(false)
    end

    it "leaves sessions still inside it" do
      described_class.perform_now

      expect(Session.exists?(active.id)).to be(true)
    end
  end

  it "runs on a queue a worker polls" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
