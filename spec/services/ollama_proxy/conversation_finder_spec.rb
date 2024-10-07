RSpec.describe OllamaProxy::ConversationFinder do
  subject { described_class.new(chat_request, user) }

  let(:chat_request) { OllamaProxy::ChatRequest.new(controller_request) }
  let(:controller_request) { instance_double(ActionDispatch::Request, raw_post:, request_method:, path:) }
  let(:raw_post) do
    {
      model: "llama3",
      messages: [
        { role: "user", content: "why is the sky blue?" },
        { role: "assistant", content: "due to rayleigh scattering." },
        { role: "user", content: "how is that different than diffraction?" },
      ],
    }.to_json
  end
  let(:request_method) { "POST" }
  let(:path) { "/api/chat" }
  let(:user) { create(:user) }

  describe "#find_or_create" do
    it "creates a new Conversation" do
      expect { subject.find_or_create }.to change(Conversation, :count).by(1)
    end

    it "creates 3 messages" do
      expect { subject.find_or_create }.to change(Message, :count).by(3)
    end

    it "creates messages with the correct contents" do
      subject.find_or_create
      expect(Message.order(:id).last(3).map(&:content)).to eq(
        [
          "why is the sky blue?",
          "due to rayleigh scattering.",
          "how is that different than diffraction?",
        ]
      )
    end

    it "creates messages with the correct authors" do
      subject.find_or_create
      expect(Message.order(:id).last(3).map(&:author)).to eq(
        [
          user,
          ModelConfig.last,
          user,
        ]
      )
    end

    it "creates a ModelConfig for the model in the request" do
      expect { subject.find_or_create }.to change(ModelConfig, :count).by(1)
      expect(ModelConfig.last.model).to eq("llama3")
    end

    context "when conversation already exists" do
      let(:conversation) { create(:conversation, user:, messages: []) }
      let(:model_config) { create(:model_config, model: "llama3") }
      let(:first_message_content) { "why is the sky blue?" }
      let(:second_message_content) { "due to rayleigh scattering." }
      let(:first_message_raw_content) { first_message_content }
      let(:second_message_raw_content) { second_message_content }
      let(:first_message_author) { user }
      let(:second_message_author) { model_config }

      before do
        Message.create(
          conversation:,
          content: first_message_content,
          raw_content: first_message_raw_content,
          author: first_message_author
        )
        Message.create(
          conversation:,
          content: second_message_content,
          raw_content: second_message_raw_content,
          author: second_message_author
        )
      end

      it "does not create a new conversation" do
        expect { subject.find_or_create }.not_to change(Conversation, :count)
      end

      it "creates only the new message" do
        expect { subject.find_or_create }.to change(Message, :count).by(1)
      end

      context "when one message has different content than the given request" do
        let(:second_message_content) { "due to reasons beyond our control..." }

        it "creates a new conversation" do
          expect { subject.find_or_create }.to change(Conversation, :count).by(1)
        end

        it "creates 3 messages" do
          expect { subject.find_or_create }.to change(Message, :count).by(3)
        end
      end

      context "when one message has a different author than the given request" do
        let(:first_message_author) { model_config }

        it "creates a new conversation" do
          expect { subject.find_or_create }.to change(Conversation, :count).by(1)
        end

        it "creates 3 messages" do
          expect { subject.find_or_create }.to change(Message, :count).by(3)
        end
      end

      context "when the raw_content of a message does not match the content" do
        let(:first_message_content) { "why is the sky blue?" }
        let(:second_message_content) { "due to rayleigh scattering.<br>\n" }
        let(:first_message_raw_content) { "why is the sky blue?" }
        let(:second_message_raw_content) { "due to rayleigh scattering.\n" }
        let(:raw_post) do
          {
            model: "llama3",
            messages: [
              { role: "user", content: "why is the sky blue?" },
              { role: "assistant", content: "due to rayleigh scattering.\n" },
              { role: "user", content: "how is that different than diffraction?" },
            ],
          }.to_json
        end

        it "does not create a new conversation" do
          expect { subject.find_or_create }.not_to change(Conversation, :count)
        end

        it "creates only the new message" do
          expect { subject.find_or_create }.to change(Message, :count).by(1)
        end
      end
    end
  end
end
