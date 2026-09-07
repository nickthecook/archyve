require 'rails_helper'

RSpec.describe User, type: :model do
  describe "#email_address" do
    subject(:user) { described_class.new(email_address: input, password: "sufficiently-long-password") }

    let(:result) { user.tap(&:valid?).email_address }

    context "when it has surrounding whitespace" do
      let(:input) { "  nick@example.com  " }

      it "strips it" do
        expect(result).to eq("nick@example.com")
      end
    end

    context "when it is mixed case" do
      let(:input) { "Nick@Example.COM" }

      it "downcases it" do
        expect(result).to eq("nick@example.com")
      end
    end
  end

  describe "validation" do
    subject(:user) { build(:user, email_address:) }

    let(:result) { user.valid? }

    context "when the email address is blank" do
      let(:email_address) { "" }

      it "is invalid" do
        expect(result).to be(false)
      end
    end

    context "when another user already has that email address" do
      let(:email_address) { "taken@example.com" }

      before { create(:user, email_address: "taken@example.com") }

      it "is invalid" do
        expect(result).to be(false)
      end
    end

    # Normalization runs before validation, so a differently-cased duplicate has
    # to collide too — otherwise the unique index would reject it at the database
    # instead, as a 500 rather than a form error.
    context "when another user has that email address in a different case" do
      let(:email_address) { "Taken@Example.com" }

      before { create(:user, email_address: "taken@example.com") }

      it "is invalid" do
        expect(result).to be(false)
      end
    end
  end

  describe ".authenticate_by" do
    subject(:result) { described_class.authenticate_by(email_address:, password:) }

    let!(:user) { create(:user, email_address: "nick@example.com", password: "correct-horse-battery") }

    context "when the email address and password match" do
      let(:email_address) { "nick@example.com" }
      let(:password) { "correct-horse-battery" }

      it "returns the user" do
        expect(result).to eq(user)
      end
    end

    context "when the email address differs only by case" do
      let(:email_address) { "NICK@example.com" }
      let(:password) { "correct-horse-battery" }

      it "returns the user" do
        expect(result).to eq(user)
      end
    end

    context "when the password is wrong" do
      let(:email_address) { "nick@example.com" }
      let(:password) { "wrong" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when no user has that email address" do
      let(:email_address) { "nobody@example.com" }
      let(:password) { "correct-horse-battery" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#at_least?" do
    subject(:user) { build(:user, role:) }

    let(:result) { user.at_least?(:operator) }

    context "when the user's role is below it" do
      let(:role) { :user }

      it "is false" do
        expect(result).to be(false)
      end
    end

    context "when the user's role is exactly it" do
      let(:role) { :operator }

      it "is true" do
        expect(result).to be(true)
      end
    end

    # Ordered roles are the whole point: an admin passes an operator gate
    # without being named in it.
    context "when the user's role is above it" do
      let(:role) { :admin }

      it "is true" do
        expect(result).to be(true)
      end
    end
  end

  # Guards the state that makes Archyve unadministrable. Enforced on the record
  # rather than in a controller so no path — console, seeds, a future API — can
  # route around it.
  describe "the last admin" do
    subject(:admin) { create(:user, :admin) }

    context "when they are the only admin and are demoted" do
      let(:result) { admin.update(role: :operator) }

      it "is refused" do
        expect(result).to be(false)
      end

      it "keeps the role" do
        result
        expect(admin.reload.role).to eq("admin")
      end
    end

    context "when they are the only admin and are destroyed" do
      let(:result) { admin.destroy }

      it "is refused" do
        expect(result).to be(false)
      end

      it "keeps the account" do
        result
        expect(User.exists?(admin.id)).to be(true)
      end
    end

    context "when another admin exists" do
      let(:result) { admin.update(role: :operator) }

      before { create(:user, :admin) }

      it "allows the demotion" do
        expect(result).to be(true)
      end
    end
  end

  # The failure this guards against: an admin removing a departing employee and
  # silently destroying every document that person ever uploaded, because a
  # Source destroys its documents and the documents cascade to chunks and
  # embeddings. The owner goes; the archive stays.
  describe "#sources" do
    subject(:user) { create(:user) }

    let!(:source) { create(:source, user:) }
    let!(:document) { create(:document, source:) }

    context "when the user is destroyed" do
      before { user.destroy }

      it "keeps the source" do
        expect(Source.exists?(source.id)).to be(true)
      end

      it "leaves the source unowned" do
        expect(source.reload.user).to be_nil
      end

      it "keeps the documents the source produced" do
        expect(Document.exists?(document.id)).to be(true)
      end
    end
  end

  describe "#sessions" do
    subject(:user) { create(:user) }

    let(:result) { Session.where(id: session.id).exists? }
    let!(:session) { user.sessions.create! }

    context "when the user is destroyed" do
      before { user.destroy }

      it "destroys its sessions too" do
        expect(result).to be(false)
      end
    end
  end
end
