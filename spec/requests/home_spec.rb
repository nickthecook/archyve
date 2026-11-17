require "rails_helper"

# The corridor's bar is the way into the archive. It asks rather than searches:
# an answer drawn from the documents beats a list of chunks, and every role gets
# the same way in.
RSpec.describe "The corridor", type: :request do
  subject(:request) { get root_path }

  # Chat needs both, or the bar falls back to searching.
  let!(:embedding) { create(:embedding_model) }
  let!(:chat_model) { create(:inference_model, :tools, name: "gpt-oss:20b") }

  it "renders" do
    request
    expect(response).to have_http_status(:ok)
  end

  it "asks rather than searches" do
    request
    expect(response.body).to include(%(action="#{conversations_path}")).and include(%(name="message"))
  end

  it "does not post the question to search" do
    request
    expect(response.body).not_to include(%(action="#{search_path}"))
  end

  # The landing has no top bar, so its footer carries the account menu instead.
  it "offers the account menu" do
    request
    expect(response.body).to include(current_user.email_address, account_path)
  end

  it "links to help" do
    request
    expect(response.body).to include(%(href="#{help_path}"))
  end

  # Starting a chat is a POST, so the corridor needs a token like any other form.
  it "carries a CSRF token" do
    request
    expect(response.body).to include("authenticity_token")
  end

  context "when several models can chat" do
    before { create(:inference_model, :tools, name: "qwen3:8b") }

    it "offers no choice, leaving it to the default" do
      request
      expect(response.body).not_to include(%(name="inference_model_id"))
    end
  end

  # The role decides which sections appear, not whether you can ask.
  context "when signed in as a visitor" do
    before { sign_in(create(:user)) }

    it "still asks" do
      request
      expect(response.body).to include(%(action="#{conversations_path}"))
    end

    it "offers no Collections facet" do
      request
      expect(response.body).not_to include(collections_path)
    end
  end

  describe "behind the bar" do
    let(:image) { Rack::Test::UploadedFile.new(file_fixture("logo.png"), "image/png") }

    context "by default" do
      it "draws the corridor" do
        request
        expect(response.body).to include("rings")
      end
    end

    context "when the corridor is turned off" do
      before { Setting["brand.corridor"] = false }

      it "draws nothing" do
        request
        expect(response.body).not_to include("rings", "hall-image")
      end

      context "with a landing image" do
        before { Setting["brand.landing_image"] = image }

        it "shows the image" do
          request
          expect(response.body).to include("hall-image")
        end
      end
    end

    context "when the corridor is on and there's a landing image too" do
      before { Setting["brand.landing_image"] = image }

      it "keeps the corridor" do
        request
        expect(response.body).not_to include("hall-image")
      end
    end
  end
end
