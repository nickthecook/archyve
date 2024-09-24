require 'rails_helper'

RSpec.describe "V1::Messages" do
  include_context "authenticated api client"

  let(:params) { nil }
  let(:conversation) { create(:conversation, messages: []) }

  describe "GET /index" do
    context "when there are fewer than a page of messages" do
      let!(:message_one) { create(:message, conversation:) }
      let!(:message_two) { create(:message, conversation:) }

      before do
        get "/v1/conversations/#{conversation.id}/messages", params:, headers:
      end

      it "returns 200" do
        expect(response).to be_successful
      end

      it "returns two messages" do
        expect(response.parsed_body["messages"].count).to eq(2)
      end

      it "returns the messages" do
        expect(response.parsed_body["messages"].first).to eq({
          "id" => message_one.id,
          "content" => message_one.content,
          "raw_content" => message_one.raw_content,
          "statistics" => message_one.statistics,
          "error" => message_one.error,
          "prompt" => message_one.prompt,
          "created_at" => message_one.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "updated_at" => message_one.updated_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "author_type" => message_one.author_type,
          "author" => message_one.author_id,
          "conversation" => conversation.id,
        })
        expect(response.parsed_body["messages"].second).to eq({
          "id" => message_two.id,
          "content" => message_two.content,
          "raw_content" => message_two.raw_content,
          "statistics" => message_two.statistics,
          "error" => message_two.error,
          "prompt" => message_two.prompt,
          "created_at" => message_two.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "updated_at" => message_two.updated_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "author_type" => message_two.author_type,
          "author" => message_two.author_id,
          "conversation" => conversation.id,
        })
      end
    end

    context "when there are more than a page of messages" do
      let(:params) { { count: 5 } }

      before do
        create_list(:message, 10, conversation:)

        get "/v1/conversations/#{conversation.id}/messages", params:, headers:
      end

      it "returns 200" do
        expect(response).to be_successful
      end

      it "returns the requested number of messages" do
        expect(response.parsed_body["messages"].count).to eq(5)
      end

      it "includes paging info" do
        expect(response.parsed_body["page"]).to eq({
          "total" => 10,
          "items" => params[:count],
          "page" => 1,
          "pages" => 2,
        })
      end
    end
  end

  describe "GET /v1/conversations/:id/messages/:id" do
    let!(:message) { create(:message, conversation:) }

    before do
      get "/v1/conversations/#{conversation.id}/messages/#{message.id}", params:, headers:
    end

    it "returns 200" do
      expect(response).to be_successful
    end

    it "returns the message" do
      expect(response.parsed_body).to eq({
        "id" => message.id,
        "content" => message.content,
        "raw_content" => message.raw_content,
        "statistics" => message.statistics,
        "error" => message.error,
        "prompt" => message.prompt,
        "created_at" => message.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
        "updated_at" => message.updated_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
        "author_type" => message.author_type,
        "author" => message.author_id,
        "conversation" => conversation.id,
      })
    end
  end
end
