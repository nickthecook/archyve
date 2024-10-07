require 'rails_helper'

RSpec.describe "V1::Conversations" do
  include_context "when api client is authenticated"

  let(:params) { nil }

  context "when there are fewer than a page of conversations" do
    let(:conversation_one) { create(:conversation, title: "hello", model_config: create(:model_config), messages: []) }
    let(:conversation_two) { create(:conversation, title: "hello again", model_config: create(:model_config), messages: []) }

    before do
      create(:message, conversation: conversation_one)
      create(:message, conversation: conversation_two)
      create(:message, conversation: conversation_two)

      get "/v1/conversations", params:, headers:
    end

    describe "GET /v1/conversations" do
      it "returns a list of conversations, most recent first" do
        expect(response.parsed_body["conversations"]).to eq([
          {
            "id" => conversation_two.id,
            "title" => conversation_two.title,
            "message_count" => 2,
            "model" => conversation_two.model_config_id,
          },
          {
            "id" => conversation_one.id,
            "title" => conversation_one.title,
            "message_count" => 1,
            "model" => conversation_one.model_config_id,
          },
        ])
      end

      it "includes paging info" do
        expect(response.parsed_body["page"]).to eq({
          "page" => 1,
          "items" => 20,
          "total" => 2,
          "pages" => 1,
          "in" => 2,
        })
      end
    end

    context "when there are more conversations than the count param" do
      let(:params) { { count: 5 } }

      before do
        create_list(:conversation, 10)

        get "/v1/conversations", params:, headers:
      end

      it "returns only the first 5 conversations" do
        expect(response.parsed_body["conversations"].size).to eq(5)
      end
    end
  end

  describe "GET /v1/conversations/:id" do
    let(:conversation) { create(:conversation, model_config: create(:model_config), messages: []) }

    before do
      create(:message, conversation:, content: "hello")
      create(:message, conversation:, content: "hello back")

      get "/v1/conversations/#{conversation.id}", params:, headers:
    end

    it "returns the conversation" do
      expect(response.parsed_body).to eq({
        "conversation" => {
          "id" => conversation.id,
          "title" => conversation.title,
          "message_count" => 2,
          "model" => conversation.model_config_id,
        },
      })
    end
  end
end
