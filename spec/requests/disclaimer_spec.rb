require "rails_helper"

RSpec.describe "The disclaimer", type: :request do
  let(:conversation) { create(:conversation, user: current_user) }

  before do
    create(:embedding_model)
    create(:inference_model, :tools)
  end

  {
    "the landing page" => -> { root_path },
    "Chat" => -> { conversations_path },
    "a conversation" => -> { conversation_path(conversation) }
  }.each do |page, path|
    describe "on #{page}" do
      subject(:request) { get instance_exec(&path) }

      before { Setting["brand.disclaimer"] = "AI can make mistakes." }

      it "is shown" do
        request
        expect(response.body).to include("AI can make mistakes.")
      end
    end
  end

  context "when none has been set" do
    it "leaves no empty line on the landing page" do
      get root_path
      expect(response.body).not_to include("ask-disclaimer")
    end
  end
end
