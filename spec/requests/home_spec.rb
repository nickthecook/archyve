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

        it "shows it in both themes" do
          request
          expect(response.body).not_to include("light:hidden")
        end

        context "and a light mode one" do
          before { Setting["brand.landing_image_light"] = image }

          it "leaves the theme to choose between them" do
            request
            expect(response.body).to include("hall-image reveal light:hidden").and include("hall-image reveal hidden light:inline")
          end
        end

        it "keeps it within the corridor's frame" do
          request
          expect(response.body).not_to include("hall-image reveal fill")
        end

        context "when it fills the screen" do
          before { Setting["brand.landing_image_fill"] = true }

          it "draws it outside the frame" do
            request
            expect(response.body).to match(/class="hall-image reveal fill"[^>]*>\s*<div class="hall-inner">/)
          end

          it "draws it once" do
            request
            expect(response.body.scan("hall-image").size).to eq(1)
          end
        end

        it "shows it at full strength" do
          request
          expect(response.body).not_to include("faded")
        end

        context "when it's faded" do
          before { Setting["brand.landing_image_fade"] = true }

          it "fades it" do
            request
            expect(response.body).to include("hall-image reveal faded")
          end
        end
      end

      context "with only a light mode landing image" do
        before { Setting["brand.landing_image_light"] = image }

        it "shows the image" do
          request
          expect(response.body).to include("hall-image")
        end

        it "shows it in both themes" do
          request
          expect(response.body).not_to include("light:hidden")
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

  describe "the shadow under the disclaimer" do
    let(:image) { Rack::Test::UploadedFile.new(file_fixture("logo.png"), "image/png") }

    context "without a disclaimer" do
      it "isn't cast" do
        request
        expect(response.body).not_to include("shaded")
      end
    end

    context "with a disclaimer" do
      before { Setting["brand.disclaimer"] = "Answers may be wrong." }

      context "over the corridor" do
        it "is cast" do
          request
          expect(response.body).to include("ask-below shaded")
        end
      end

      context "when the corridor is turned off" do
        before { Setting["brand.corridor"] = false }

        it "isn't cast" do
          request
          expect(response.body).not_to include("shaded")
        end

        context "with a landing image" do
          before { Setting["brand.landing_image"] = image }

          it "is cast" do
            request
            expect(response.body).to include("ask-below shaded")
          end
        end
      end
    end
  end

  describe "the reduce motion switch" do
    context "over the corridor" do
      it "is offered" do
        request
        expect(response.body).to include("reduce motion")
      end
    end

    context "when the corridor is turned off" do
      before { Setting["brand.corridor"] = false }

      it "isn't offered" do
        request
        expect(response.body).not_to include("reduce motion")
      end
    end
  end
end
