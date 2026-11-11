require "rails_helper"

# A fresh clone has no inference server at all — nothing exists unless
# ARCHYVE_INFERENCE provisions one. Every page a person can reach in that state has to say
# so plainly rather than fall over on a nil.
RSpec.describe "An unconfigured install", :unauthenticated, type: :request do
  before { sign_in(create(:user, :admin)) }

  it "has no embedding model" do
    expect(InferenceModel.active_embedding).to be_nil
  end

  describe "the corridor" do
    subject(:request) { get root_path }

    it "renders" do
      request
      expect(response).to have_http_status(:ok)
    end

    it "says inference isn't configured" do
      request
      expect(response.body).to include("not configured")
    end

    # The bar asks a question once there is something to answer it. With no
    # chat model it does the thing that still works rather than posting a
    # question into the void.
    it "falls back to searching" do
      request
      expect(response.body).to include(%(action="#{search_path}")).and include(%(name="q"))
    end

    it "does not offer to start a chat" do
      request
      expect(response.body).not_to include(%(action="#{conversations_path}"))
    end

    it "says why, where the hint goes" do
      request
      expect(response.body).to include("Chat needs a tool-capable chat model")
    end
  end

  describe "search" do
    subject(:request) { get search_path, params: { q: "anything" } }

    it "renders rather than erroring" do
      request
      expect(response).to have_http_status(:ok)
    end

    # A different cause from an unreachable host, so a different message — and
    # only an admin is told where to fix it.
    it "points the admin at settings" do
      request
      expect(response.body).to include("Settings")
    end

    context "when signed in as a visitor" do
      before { sign_in(create(:user)) }

      it "doesn't send them somewhere they can't go" do
        request
        expect(response.body).to include("Search isn&#39;t available yet")
      end
    end
  end

  describe "settings" do
    subject(:request) { get settings_path }

    it "renders" do
      request
      expect(response).to have_http_status(:ok)
    end
  end

  describe "chat" do
    subject(:request) { get conversations_path }

    it "renders" do
      request
      expect(response).to have_http_status(:ok)
    end
  end
end
