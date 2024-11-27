require 'rails_helper'

RSpec.describe Conversation do
  describe '#add_system_message' do
    subject { create(:conversation_with_no_messages) }

    context 'when system_prompt setting exists' do
      let(:system_prompt) { "You are Archyve, an AI assistant..." }

      before do
        Setting.create!(key: 'system_prompt', value: system_prompt)
      end

      it 'creates a system message with the prompt' do
        first_message = subject.messages.first
        expect(first_message).to be_present
        expect(first_message.content).to eq(system_prompt)
        expect(first_message.author).to be_nil
      end
    end

    context 'when system_prompt setting does not exist' do
      it 'does not create a system message' do
        expect(subject.messages).to be_empty
      end
    end
  end

  describe "#first_user_message?" do
    subject { create(:conversation) }

    it "returns false since the conversation has many User messages" do
      expect(subject.first_user_message?).to be_falsey
    end
  end
end
