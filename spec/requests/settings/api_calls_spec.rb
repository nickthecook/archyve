require "rails_helper"

RSpec.describe "Settings::ApiCalls", :unauthenticated, type: :request do
  before { sign_in(create(:user, :admin)) }

  describe "GET /settings/api_calls" do
    subject(:request) { get settings_api_calls_path }

    # The Older button's href, whatever cursor and filters it happens to carry.
    def older_link = response.body[/href="([^"]*after=[^"]*)"/, 1]&.then { CGI.unescapeHTML(it) }

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
      before { create(:api_call, url: "http://tensor:11434/v1/chat/completions", kind: "chat", duration_ms: 1234) }

      # The host, not the service: "ollama" is the client stack the call went
      # through, which doesn't say which of two Ollama servers answered.
      it "lists where it went and what came back" do
        request
        expect(response.body).to include("tensor", "chat", "200", "1,234 ms")
      end
    end

    describe "filtering" do
      let!(:chat) { create(:api_call, kind: "chat", url: "http://tensor:11434/v1/chat/completions") }
      let!(:discovery) { create(:api_call, kind: "discovery", url: "https://i.rmtly.com/v1/models") }

      # `host` is also url_for's option for the host of the URL it is building,
      # so a path helper swallows it — see ApiCalls::Listing.
      def filter(**values) = get(settings_api_calls_path(params: values))

      def lists?(call) = response.body.include?(%(href="#{settings_api_call_path(call)}"))

      context "by kind" do
        it "keeps that kind and drops the others" do
          filter(kind: "discovery")
          expect(lists?(discovery)).to be(true)
          expect(lists?(chat)).to be(false)
        end
      end

      context "by host" do
        it "keeps that host and drops the others" do
          filter(host: "tensor")
          expect(lists?(chat)).to be(true)
          expect(lists?(discovery)).to be(false)
        end
      end

      context "by both at once" do
        it "narrows to what matches neither" do
          filter(kind: "chat", host: "i.rmtly.com")
          expect(response.body).to include("No calls match.")
        end
      end

      # The filters are a URL anyone can edit, and a host whose last call has
      # been swept is a stale bookmark rather than an error.
      context "with a value that isn't on offer" do
        it "ignores it rather than refusing" do
          filter(host: "nowhere.test")
          expect(lists?(chat)).to be(true)
          expect(lists?(discovery)).to be(true)
        end
      end

      it "offers every host that was called" do
        request
        expect(response.body).to include(%(<option value="tensor">), %(<option value="i.rmtly.com">))
      end
    end

    describe "paging" do
      before { stub_const("Page::PER_PAGE", 1) }

      let!(:older) { create(:api_call, created_at: 2.hours.ago, url: "http://tensor:11434/v1/chat/completions") }
      let!(:newer) { create(:api_call, created_at: 1.hour.ago, url: "https://i.rmtly.com/v1/chat/completions") }

      def lists?(call) = response.body.include?(%(href="#{settings_api_call_path(call)}"))

      it "shows the newest screen first, with a way on and none back" do
        request
        expect(lists?(newer)).to be(true)
        expect(lists?(older)).to be(false)
        expect(response.body).to include("Older →")
        expect(response.body).not_to include("Newer")
      end

      it "follows Older to the next screen" do
        request
        get older_link
        expect(lists?(older)).to be(true)
        expect(lists?(newer)).to be(false)
      end

      it "keeps the filters while paging" do
        get settings_api_calls_path(params: { kind: "chat" })
        expect(older_link).to include("kind=chat")
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
