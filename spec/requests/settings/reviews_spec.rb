require "rails_helper"

RSpec.describe "Settings::Reviews", :unauthenticated, type: :request do
  let(:asker) { create(:user, email_address: "asker@example.com") }
  let(:conversation) { create(:conversation, user: asker, title: "Rotating credentials") }

  def turn(question:, answer:, position:, error: nil)
    create(:segment, message: create(:message, conversation:, position:), content: question)
    create(:message, conversation:, role: "assistant", position: position + 1, completed_at: 1.minute.ago, error:)
      .tap { create(:segment, message: it, content: answer) unless error }
  end

  before { sign_in(create(:user, :admin)) }

  describe "GET /settings/review" do
    subject(:request) { get settings_review_path, params: }

    let(:params) { {} }
    let!(:rated) { turn(question: "How often do keys rotate?", answer: "Every 90 days.", position: 1) }
    let!(:unrated) { turn(question: "Who owns the bastion?", answer: "Platform team.", position: 3) }

    before { create(:feedback, message: rated, rating: "down", comment: "It's 30 days now.") }

    context "with no filter chosen" do
      before { request }

      it "shows answers with feedback, and what was said" do
        expect(response.body).to include("How often do keys rotate?", "Every 90 days.", "It&#39;s 30 days now.")
      end

      it "leaves out answers without any" do
        expect(response.body).not_to include("Who owns the bastion?")
      end

      it "doesn't name who asked" do
        expect(response.body).not_to include("asker@example.com")
      end

      it "links to the answer's prose in its chat, past any thinking or searching" do
        expect(response.body).to include(
          settings_review_chat_path(conversation, anchor: "prose_#{ActionView::RecordIdentifier.dom_id(rated.segments.last)}")
        )
      end
    end

    context "when asking for all answers" do
      let(:params) { { feedback: "" } }

      before { request }

      it "includes those without feedback" do
        expect(response.body).to include("Who owns the bastion?")
      end

      it "exports what it shows" do
        expect(response.body).to include(%(href="/settings/review.csv?feedback="))
      end
    end

    context "when asking for failed answers" do
      let(:params) { { feedback: "", outcome: "failed" } }

      before { turn(question: "What is the VPN address?", answer: nil, error: "The model server went away.", position: 5) }

      before { request }

      it "shows them" do
        expect(response.body).to include("The model server went away.")
      end

      it "leaves out the answered ones" do
        expect(response.body).not_to include("Every 90 days.")
      end
    end

    context "with more answers than fit on a page" do
      let(:params) { { feedback: "" } }

      def older_link = response.body[/href="([^"]*after=[^"]*)"/, 1]&.then { CGI.unescapeHTML(it) }

      before do
        stub_const("Reviews::Listing::PER_PAGE", 1)
        rated.update!(created_at: 1.hour.ago)
        request
      end

      it "shows the newest first" do
        expect(response.body).to include("Who owns the bastion?").and(include("Older →"))
      end

      it "follows Older to the next screen" do
        get older_link
        expect(response.body).to include("How often do keys rotate?")
      end

      it "keeps the filter turned off on the next screen" do
        expect(older_link).to match(/[?&]feedback=(&|\z)/)
      end
    end

    context "when signed in below admin" do
      before { sign_in(create(:user, :operator)) }

      it "refuses" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /settings/review.csv" do
    subject(:request) { get settings_review_path(format: :csv), params: }

    let(:params) { {} }
    let(:csv) { CSV.parse(response.body, headers: true) }
    let!(:rated) { turn(question: "How often do keys rotate?", answer: "Every 90 days.", position: 1) }

    before do
      turn(question: "Who owns the bastion?", answer: "Platform team.", position: 3)
      create(:feedback, message: rated, rating: "down", comment: comment)
    end

    let(:comment) { "It's 30 days now." }

    context "with no filter chosen" do
      before { request }

      it "exports the answers with feedback, as the page shows them" do
        expect(csv.map(&:to_h)).to contain_exactly(
          a_hash_including("Question" => "How often do keys rotate?", "Answer" => "Every 90 days.",
            "Rating" => "bad", "Comment" => "It's 30 days now.")
        )
      end

      it "doesn't name who asked" do
        expect(response.body).not_to include("asker@example.com")
      end
    end

    context "when asking for all answers" do
      let(:params) { { feedback: "" } }

      it "exports those without feedback too" do
        request
        expect(csv.map { it["Question"] }).to contain_exactly("How often do keys rotate?", "Who owns the bastion?")
      end
    end

    context "when the answer drew on documents" do
      before do
        search = create(:retrieval_segment, message: rated, position: 2)
        create(:hit, segment: search, document_title: "Security Handbook")
        request
      end

      it "names them" do
        expect(csv.first["Documents"]).to eq("Security Handbook")
      end
    end

    context "when a comment would run as a spreadsheet formula" do
      let(:comment) { "=HYPERLINK(\"http://evil.example\")" }

      it "keeps it as text" do
        request
        expect(csv.first["Comment"]).to eq("'=HYPERLINK(\"http://evil.example\")")
      end
    end
  end

  describe "GET /settings/review/chats/:id" do
    subject(:request) { get settings_review_chat_path(conversation) }

    let!(:answer) { turn(question: "How often do keys rotate?", answer: "Every 90 days.", position: 1) }

    before do
      create(:feedback, message: answer, rating: "up", comment: "Spot on.")
      request
    end

    it "shows the transcript and its feedback" do
      expect(response.body).to include("How often do keys rotate?", "Every 90 days.", "Spot on.")
    end

    it "doesn't name who asked" do
      expect(response.body).not_to include("asker@example.com")
    end

    it "offers no way to change the feedback" do
      expect(response.body).not_to include(conversation_message_feedback_path(conversation, answer))
    end
  end
end
