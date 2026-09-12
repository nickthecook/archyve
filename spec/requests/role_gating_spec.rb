require "rails_helper"

# The ceiling, from both sides. Controllers enforce it; Views::Chrome and the
# landing only hide the links, so these are the examples that matter.
RSpec.describe "Role gating", :unauthenticated, type: :request do
  subject(:request) { get path }

  before { sign_in(create(:user, *traits)) }

  shared_examples "refused" do
    it "redirects to the corridor" do
      request
      expect(response).to redirect_to(root_path)
    end

    it "says why" do
      request
      expect(flash[:alert]).to eq("You don't have access to that.")
    end
  end

  shared_examples "allowed" do
    it "renders" do
      request
      expect(response).to have_http_status(:ok)
    end
  end

  describe "an operator-only page" do
    let(:path) { sources_path }

    context "when signed in as a user" do
      let(:traits) { [] }

      include_examples "refused"
    end

    context "when signed in as an operator" do
      let(:traits) { [:operator] }

      include_examples "allowed"
    end

    context "when signed in as an admin" do
      let(:traits) { [:admin] }

      # Ordered roles, so admin needs no separate grant to pass an operator gate.
      include_examples "allowed"
    end
  end

  describe "an admin-only page" do
    let(:path) { settings_path }

    context "when signed in as an operator" do
      let(:traits) { [:operator] }

      include_examples "refused"
    end

    context "when signed in as an admin" do
      let(:traits) { [:admin] }

      include_examples "allowed"
    end
  end

  describe "the inference settings" do
    let(:path) { settings_inference_servers_path }

    context "when signed in as an operator" do
      let(:traits) { [:operator] }

      # An operator manages content. Repointing Archyve at a different LLM host
      # is system administration, which is why InferenceServer has no per-object
      # grant to soften this.
      include_examples "refused"
    end

    context "when signed in as an admin" do
      let(:traits) { [:admin] }

      include_examples "allowed"
    end
  end

  describe "a page open to everyone" do
    let(:path) { conversations_path }

    context "when signed in as a user" do
      let(:traits) { [] }

      include_examples "allowed"
    end
  end

  describe "the account page" do
    let(:path) { account_path }

    context "when signed in as a user" do
      let(:traits) { [] }

      # Gating this would leave most people unable to change their own password.
      include_examples "allowed"
    end
  end

  describe "the corridor" do
    let(:path) { root_path }

    context "when signed in as a user" do
      let(:traits) { [] }

      include_examples "allowed"

      it "offers no door to Collections" do
        request
        expect(response.body).not_to include(collections_path)
      end

      it "offers no door to Settings" do
        request
        expect(response.body).not_to include(settings_path)
      end
    end

    context "when signed in as an admin" do
      let(:traits) { [:admin] }

      it "offers every door" do
        request
        expect(response.body).to include(settings_path)
      end
    end
  end
end
