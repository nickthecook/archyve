require 'rails_helper'

RSpec.describe Message do
  subject { create(:message, content: "why is the sky blue?", conversation:) }

  let(:conversation) { create(:conversation, messages: []) }

  before do
    create(:message, conversation:)
    create(:message, conversation:)
    conversation.messages << subject
    create(:message, conversation:)
    create(:message, conversation:)

    conversation.reload
  end

  describe "#previous" do
    it "returns the previous message" do
      expect(subject.previous).to contain_exactly(conversation.messages.order(:id)[1])
    end

    it "returns multiple messages" do
      expect(subject.previous(2)).to eq(conversation.messages.order(:id)[0..1])
    end

    it "stops at the beginning of the list" do
      expect(subject.previous(3)).to eq(conversation.messages.order(:id)[0..1])
    end
  end

  describe "#next" do
    it "returns the next message" do
      expect(subject.next).to contain_exactly(conversation.messages.order(:id)[3])
    end

    it "returns multiple messages" do
      expect(subject.next(2)).to eq(conversation.messages.order(:id)[3..4])
    end

    it "stops at the end of the list" do
      expect(subject.next(3)).to eq(conversation.messages.order(:id)[3..4])
    end
  end
end
