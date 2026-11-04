require "rails_helper"

RSpec.describe "Settings::Agents", :unauthenticated, type: :request do
  let(:user) { create(:user, :admin) }

  before { sign_in(user) }

  describe "GET /settings/agents" do
    subject(:request) { get settings_agents_path }

    it "lists the agents" do
      request
      expect(response.body).to include("Archivist")
    end

    it "lists the toolsets and who may use them" do
      request
      expect(response.body).to include("Archive").and include("Everyone")
    end

    it "offers the instance purpose" do
      request
      expect(response.body).to include("Instance purpose")
    end

    context "when a purpose has been set" do
      before { Setting["chat.instance_purpose"] = "Answer questions for my family." }

      it "shows it" do
        request
        expect(response.body).to include("Answer questions for my family.")
      end
    end

    context "when signed in as a curator" do
      let(:user) { create(:user, :curator) }

      it "refuses" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /settings/agents/:slug" do
    subject(:request) { get settings_agent_path(agent) }

    let(:agent) { Agent.archivist }

    it "shows the prompt" do
      request
      expect(response.body).to include(agent.prompt)
    end

    it "says it can't be changed" do
      request
      expect(response.body).to include("can&#39;t be changed")
    end

    context "when the agent doesn't exist" do
      let(:agent) { "nobody" }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as a curator" do
      let(:user) { create(:user, :curator) }

      it "refuses" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
