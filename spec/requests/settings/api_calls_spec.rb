require "rails_helper"

RSpec.describe "Settings::ApiCalls", :unauthenticated, type: :request do
  before { sign_in(create(:user, :admin)) }

  describe "GET /settings/api_calls" do
    subject(:request) { get settings_api_calls_path }

    context "with nothing recorded and recording off" do
      before { Setting["debug.record_api_calls"] = false }

      it "says it isn't recording rather than showing an empty table" do
        request
        expect(response.body).to include("Not recording.")
      end
    end

    context "with nothing recorded and recording on" do
      before { Setting["debug.record_api_calls"] = true }

      it "says calls will appear" do
        request
        expect(response.body).to include("Nothing recorded yet.")
      end
    end

    context "with a call that was answered" do
      before { create(:api_call, service_name: "ollama", kind: "chat", duration_ms: 1234) }

      it "lists what it was and what came back" do
        request
        expect(response.body).to include("ollama", "chat", "200", "1,234 ms")
      end
    end

    context "with a call nothing answered" do
      before { create(:api_call, :refused) }

      it "says why instead of showing a status" do
        request
        expect(response.body).to include("connection refused")
      end
    end

    context "when an operator asks" do
      before { sign_in(create(:user, :operator)) }

      it "is refused — recorded bodies carry prompt and answer text" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /settings/api_calls/:id" do
    subject(:request) { get settings_api_call_path(api_call) }

    let(:api_call) { create(:api_call) }

    it "shows the request and the response" do
      request
      expect(response.body).to include("Request", "Response", "llama3.2", "An answer.")
    end

    context "when it answered a turn in the admin's own conversation" do
      let(:conversation) { create(:conversation, user: current_user, title: "Why is the server slow?") }
      let(:api_call) { create(:api_call, traceable: create(:message, conversation:)) }

      it "links back to the conversation" do
        request
        expect(response.body).to include(conversation_path(conversation), "Why is the server slow?")
      end
    end

    context "when it answered someone else's conversation" do
      let(:conversation) { create(:conversation, title: "Private question") }
      let(:api_call) { create(:api_call, traceable: create(:message, conversation:)) }

      it "names it without a link only its author can follow" do
        request
        expect(response.body).to include("Private question")
        expect(response.body).not_to include(conversation_path(conversation))
      end
    end
  end
end
