require "rails_helper"

RSpec.describe Endpoint do
  # The whole reason credentials live in their own column: whatever the shape of
  # a type's auth, none of it may be readable in the database.
  describe "credential storage" do
    subject(:endpoint) { create(:bookstack_endpoint, token_secret: "s3cret") }

    it "round-trips through a save" do
      expect(endpoint.reload.token_secret).to eq("s3cret")
    end

    it "does not store the secret in readable form" do
      stored = described_class.connection.select_value(
        "SELECT credentials FROM endpoints WHERE id = #{endpoint.id}"
      )

      expect(stored).not_to include("s3cret")
    end

    # config is the half that stays queryable, so an admin list can name the
    # host a row points at without decrypting every row to do it.
    it "leaves the non-secret half readable" do
      stored = described_class.connection.select_value(
        "SELECT config->>'base_url' FROM endpoints WHERE id = #{endpoint.id}"
      )

      expect(stored).to eq("https://wiki.example.com")
    end
  end

  describe ".credential writers" do
    subject(:endpoint) { create(:bookstack_endpoint, token_secret: "original") }

    # Assigning a new hash rather than mutating in place is what makes this
    # work; an in-place `credentials["x"] = …` leaves the attribute clean and
    # the save writes nothing.
    context "when given a new value" do
      it "persists it" do
        endpoint.update!(token_secret: "rotated")

        expect(endpoint.reload.token_secret).to eq("rotated")
      end
    end

    # An edit form renders a secret as an empty field. Submitting that form to
    # change the *name* must not wipe the token every source here depends on.
    context "when given a blank value" do
      it "leaves the stored secret alone" do
        endpoint.update!(name: "Renamed", token_secret: "")

        expect(endpoint.reload.token_secret).to eq("original")
      end
    end

    context "when given a value with surrounding whitespace" do
      it "strips it, because pasted tokens carry it" do
        endpoint.update!(token_secret: "  rotated\n")

        expect(endpoint.reload.token_secret).to eq("rotated")
      end
    end

    context "when cleared explicitly" do
      it "drops the secret" do
        endpoint.clear_credential(:token_secret)

        expect(endpoint.token_secret).to be_nil
      end
    end
  end

  describe "#base_url" do
    context "when it has a trailing slash" do
      subject(:endpoint) { build(:bookstack_endpoint, base_url: "https://wiki.example.com/") }

      # Otherwise the same wiki typed two ways becomes two rows, and the unique
      # index on `name` can't catch that.
      it "is normalized away" do
        endpoint.validate

        expect(endpoint.base_url).to eq("https://wiki.example.com")
      end
    end

    context "when it is not an http address" do
      subject(:endpoint) { build(:bookstack_endpoint, base_url: "wiki.example.com") }

      it "is rejected" do
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:base_url]).to include("must be an http:// or https:// address")
      end
    end
  end

  describe "#access" do
    subject(:endpoint) { create(:bookstack_endpoint) }

    context "when the server answers" do
      before { allow(endpoint).to receive(:access!).and_return(true) }

      it "records success" do
        expect(endpoint.access).to be(true)
        expect(endpoint).to be_accessible
        expect(endpoint.access_error).to be_nil
      end
    end

    context "when the credentials are rejected" do
      before do
        allow(endpoint).to receive(:access!).and_raise(Faraday::UnauthorizedError, "the server responded with status 401")
      end

      it "records the failure rather than raising" do
        expect(endpoint.access).to be(false)
        expect(endpoint).not_to be_accessible
        expect(endpoint.access_error).to include("401")
      end
    end

    # Both columns describe the same event, so a failed access is still an
    # access: the timestamp moves, and the error says how it went.
    context "when an endpoint that used to work stops working" do
      before do
        allow(endpoint).to receive(:access!).and_return(true)
        endpoint.access
        allow(endpoint).to receive(:access!).and_raise(Faraday::UnauthorizedError, "401")
      end

      it "records the failed attempt over the successful one" do
        expect { endpoint.access }.to change(endpoint, :accessed_at)
        expect(endpoint).not_to be_accessible
      end
    end

    context "when it has never been used" do
      it "is not accessible, and has nothing to say about why" do
        expect(endpoint).not_to be_accessible
        expect(endpoint.access_error).to be_nil
      end
    end

    context "when the error message is enormous" do
      before { allow(endpoint).to receive(:access!).and_raise(StandardError, "x" * 1000) }

      it "truncates it to something a column and a page can hold" do
        endpoint.access

        expect(endpoint.access_error.length).to be <= Endpoint::ACCESS_ERROR_LIMIT
      end
    end
  end

  # An endpoint is an address and a secret; its sources own documents, chunks
  # and embeddings that cost real money to produce.
  describe "destroying one" do
    subject(:endpoint) { create(:bookstack_endpoint) }

    context "when sources still point at it" do
      # A folder source would never really have an endpoint; it stands in here
      # for a type that does, until one exists. The restriction is on the
      # association, not on any particular source type.
      before { create(:folder_source, endpoint: endpoint) }

      it "refuses" do
        expect(endpoint.destroy).to be(false)
        expect(described_class.exists?(endpoint.id)).to be(true)
      end
    end

    context "when nothing points at it" do
      it "is allowed" do
        expect(endpoint.destroy).to be_truthy
      end
    end
  end

  # A subclass that forgets one of these should say so, not fail with a bare
  # NoMethodError from somewhere inside #access.
  describe "the endpoint contract" do
    it "names a missing #auth_headers" do
      expect { described_class.new.auth_headers }
        .to raise_error(Endpoint::MissingImplementationError, /auth_headers/)
    end

    it "names a missing #access!" do
      expect { described_class.new.access! }
        .to raise_error(Endpoint::MissingImplementationError, /access!/)
    end

    # StandardError, not ScriptError — otherwise it sails straight through the
    # rescue in #access that exists to report exactly this kind of trouble, and
    # the diagnostic becomes a 500.
    context "when a subclass has not implemented it" do
      subject(:endpoint) { create(:bookstack_endpoint) }

      before do
        allow(endpoint).to receive(:access!)
          .and_raise(Endpoint::MissingImplementationError, "must implement #access!")
      end

      it "is reported by #access rather than raised out of it" do
        expect(endpoint.access).to be(false)
        expect(endpoint.access_error).to include("access!")
      end
    end
  end
end
