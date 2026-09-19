require "rails_helper"

RSpec.describe Session, type: :model do
  let(:user) { create(:user) }

  describe "lifetime" do
    # Absolute, not sliding: revoking someone's access at the IdP only reaches a
    # browser that is already signed in once their session runs out, so the
    # clock has to start at sign-in rather than at last use.
    context "when the session is younger than LIFETIME" do
      it "is active" do
        session = user.sessions.create!(created_at: (described_class::LIFETIME - 1.minute).ago)

        expect(described_class.active).to include(session)
        expect(described_class.expired).not_to include(session)
      end
    end

    context "when the session is older than LIFETIME" do
      it "is expired" do
        session = user.sessions.create!(created_at: (described_class::LIFETIME + 1.minute).ago)

        expect(described_class.active).not_to include(session)
        expect(described_class.expired).to include(session)
      end

      # Touching it must not extend it — that would make the scope sliding.
      it "stays expired after being updated" do
        session = user.sessions.create!(created_at: (described_class::LIFETIME + 1.minute).ago)
        session.touch

        expect(described_class.expired).to include(session)
      end
    end
  end

  describe "#sso?" do
    context "with an ID token" do
      it "is an SSO session" do
        expect(user.sessions.create!(sso_id_token: "a-token")).to be_sso
      end
    end

    context "without one" do
      it "is a password session" do
        expect(user.sessions.create!).not_to be_sso
      end
    end
  end

  it "stores the ID token encrypted" do
    session = user.sessions.create!(sso_id_token: "a-token")

    expect(session.reload.sso_id_token).to eq("a-token")
    expect(described_class.connection.select_value("SELECT sso_id_token FROM sessions WHERE id = #{session.id}"))
      .not_to include("a-token")
  end
end
