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

    context "when an agent can't be the default" do
      before { create(:agent, name: "Kevin", access_mode: "granted") }

      it "lists it as unavailable, saying why" do
        request
        expect(response.body).to match(/<option value="[\w-]+" disabled>Kevin \(only people granted access\)<\/option>/)
      end
    end

    context "when no agent can be the default" do
      before { Agent.archivist.update!(access_mode: "nobody") }

      it "says none qualifies" do
        request
        expect(response.body).to include("None qualifies")
      end

      it "says why Archivist doesn't" do
        request
        expect(response.body).to include("Archivist (switched off)")
      end
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

    it "says only its access can be changed" do
      request
      expect(response.body).to include("only who can chat with it can be changed")
    end

    context "when Archivist is switched off" do
      before { agent.update!(access_mode: "nobody") }

      it "says so" do
        request
        expect(response.body).to include("No one: it&#39;s switched off")
      end
    end

    context "when it is Admin Support" do
      let(:agent) { Agent.admin_support }

      it "says it can't be changed" do
        request
        expect(response.body).to include("can&#39;t be changed")
      end

      it "offers no edit" do
        request
        expect(response.body).not_to include(edit_settings_agent_path(agent))
      end
    end

    context "when only its creator may use it" do
      let(:agent) { create(:agent, access_mode: "creator_only", creator: create(:user, email_address: "pat@example.com")) }

      it "says who" do
        request
        expect(response.body).to include("Only pat@example.com")
      end
    end

    context "when it has a fixed set of collections" do
      let(:agent) { create(:agent, collection_mode: "fixed") }

      before { create(:agent_collection, agent:, collection: create(:collection, name: "Shared handbook")) }

      it "names them" do
        request
        expect(response.body).to include("Shared handbook")
      end
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

  describe "GET /settings/agents/new" do
    it "offers the form" do
      get new_settings_agent_path
      expect(response.body).to include("Create agent")
    end

    it "names each model it could use" do
      model = create(:inference_model, :tools, name: "qwen3.8-27b")
      get new_settings_agent_path
      expect(response.body).to include(%(<option value="#{model.id}">qwen3.8-27b</option>))
    end
  end

  describe "POST /settings/agents" do
    subject(:request) { post settings_agents_path, params: { agent: attributes } }

    let(:collection) { create(:collection, name: "Handbook") }
    let(:attributes) do
      { name: "Policy bot", prompt: "You answer policy questions.", toolset_keys: ["", "archive"],
        access_mode: "everyone", collection_mode: "fixed", collection_ids: ["", collection.id.to_s] }
    end
    let(:agent) { Agent.find_by(slug: "policy-bot") }

    it "creates it" do
      expect { request }.to change(Agent, :count).by(1)
    end

    it "records who made it" do
      request
      expect(agent.creator).to eq(user)
    end

    it "keeps its collections" do
      request
      expect(agent.collections).to eq([collection])
    end

    it "goes to its page" do
      request
      expect(response).to redirect_to(settings_agent_path(agent))
    end

    context "when it draws on what each person can read" do
      let(:attributes) { super().merge(collection_mode: "user") }

      it "keeps no collections" do
        request
        expect(agent.collections).to be_empty
      end
    end

    context "without a name" do
      let(:attributes) { super().merge(name: "") }

      it "shows the form again" do
        request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "keeps what was chosen" do
        request
        expect(response.body).to include(%(value="#{collection.id}" checked))
      end
    end
  end

  describe "PATCH /settings/agents/:slug" do
    subject(:request) { patch settings_agent_path(agent), params: { agent: attributes } }

    let(:agent) { create(:agent, name: "Policy bot", access_mode: "creator_only", creator: user) }
    let(:attributes) do
      { name: "Policy bot", prompt: "Be brief.", toolset_keys: ["archive"],
        access_mode: "granted", collection_mode: "user" }
    end

    it "saves the change" do
      request
      expect(agent.reload).to have_attributes(prompt: "Be brief.", access_mode: "granted")
    end

    context "with a fixed model" do
      let(:model) { create(:inference_model, :tools) }
      let(:attributes) { super().merge(inference_model_id: model.id.to_s, model_overridable: "0") }

      it "saves it" do
        request
        expect(agent.reload).to have_attributes(inference_model: model, model_overridable: false)
      end
    end

    context "with a model that can't call tools" do
      let(:attributes) { super().merge(inference_model_id: create(:inference_model).id.to_s) }

      it "shows the form again" do
        request
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with the instance default" do
      let(:agent) { create(:agent, name: "Policy bot", creator: user, inference_model: create(:inference_model, :tools)) }
      let(:attributes) { super().merge(inference_model_id: "") }

      it "clears its own model" do
        request
        expect(agent.reload.inference_model).to be_nil
      end
    end

    context "when the agent is Archivist" do
      let(:agent) { Agent.archivist }
      let(:attributes) { super().merge(access_mode: "nobody") }

      it "changes who can chat with it" do
        request
        expect(agent.reload).to be_nobody
      end

      it "changes nothing else" do
        request
        expect(agent.reload.prompt).not_to eq("Be brief.")
      end

      context "and it is made creator-only" do
        let(:attributes) { super().merge(access_mode: "creator_only") }

        it "refuses" do
          request
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when the agent is Admin Support" do
      let(:agent) { Agent.admin_support }
      let(:attributes) { super().merge(access_mode: "nobody") }

      it "refuses" do
        request
        expect(agent.reload).to be_everyone
      end
    end
  end

  describe "GET /settings/agents/:slug/edit" do
    subject(:request) { get edit_settings_agent_path(agent) }

    context "with Archivist" do
      let(:agent) { Agent.archivist }

      it "offers switching it off" do
        request
        expect(response.body).to include('value="nobody"')
      end

      it "offers only its access" do
        request
        expect(response.body).not_to include('name="agent[prompt]"')
      end
    end

    context "with Admin Support" do
      let(:agent) { Agent.admin_support }

      it "refuses" do
        request
        expect(response).to redirect_to(settings_agent_path(agent))
      end
    end
  end

  describe "POST /settings/agents/:slug/duplicate" do
    subject(:request) { post duplicate_settings_agent_path(Agent.archivist) }

    let(:copy) { Agent.find_by(name: "Archivist (copy)") }

    it "makes a copy you can change" do
      request
      expect(copy).to have_attributes(built_in: false, creator: user, access_mode: "creator_only")
    end

    it "opens the copy for editing" do
      request
      expect(response).to redirect_to(edit_settings_agent_path(copy))
    end
  end

  describe "DELETE /settings/agents/:slug" do
    subject(:request) { delete settings_agent_path(agent) }

    let!(:agent) { create(:agent) }

    it "removes it" do
      expect { request }.to change(Agent, :count).by(-1)
    end

    context "when a conversation used it" do
      before { create(:conversation, agent:) }

      it "keeps it" do
        expect { request }.not_to change(Agent, :count)
      end
    end

    context "when it is built in" do
      let!(:agent) { Agent.archivist }

      it "keeps it" do
        expect { request }.not_to change(Agent, :count)
      end
    end
  end

  describe "the people an agent is granted to" do
    let(:agent) { create(:agent, access_mode: "granted") }
    let(:visitor) { create(:user, email_address: "sam@example.com") }

    it "grants access" do
      post settings_agent_people_path(agent), params: { user_id: visitor.id, access: "accessor" }
      expect(agent.usable_by?(visitor)).to be(true)
    end

    it "lists who has it" do
      create(:agent_user, agent:, user: visitor)
      get settings_agent_people_path(agent)
      expect(response.body).to include("sam@example.com")
    end

    context "when the agent is Archivist" do
      let(:agent) { Agent.archivist.tap { it.update!(access_mode: "granted") } }

      it "grants access" do
        post settings_agent_people_path(agent), params: { user_id: visitor.id, access: "accessor" }
        expect(agent.usable_by?(visitor)).to be(true)
      end
    end

    context "when the agent is Admin Support" do
      let(:agent) { Agent.admin_support }

      it "has no people page" do
        get settings_agent_people_path(agent)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /settings/default_agent" do
    subject(:request) { patch settings_default_agent_path, params: { agent: chosen.slug } }

    context "with an agent everyone can use" do
      let(:chosen) { create(:agent) }

      it "makes it the default" do
        request
        expect(Agent.default_chat).to eq(chosen)
      end
    end

    context "with a granted agent" do
      let(:chosen) { create(:agent, access_mode: "granted") }

      it "refuses" do
        request
        expect(Setting.chat_default_agent).to eq("archivist")
      end
    end

    context "with Admin Support" do
      let(:chosen) { Agent.admin_support }

      it "refuses" do
        request
        expect(Setting.chat_default_agent).to eq("archivist")
      end
    end
  end
end
