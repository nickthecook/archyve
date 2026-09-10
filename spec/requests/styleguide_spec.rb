require "rails_helper"

# The style guide's whole value is that it renders the *real* components, so
# these examples check exactly that — not that the page merely responds.
RSpec.describe "Styleguide", :unauthenticated, type: :request do
  subject(:request) { get styleguide_path }

  before { sign_in(create(:user, *traits)) }

  describe "GET /styleguide" do
    context "when signed in as an admin" do
      let(:traits) { [:admin] }

      it "renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      it "covers every status in the shared vocabulary" do
        request
        expect(response.body).to include(*Views::Documents::StatusBadge::COLORS.keys)
      end

      # The accent rail is Views::Doorway's signature, and rendering it exercises
      # the icon content block — the fragile part of the extraction.
      it "renders the real doorway component" do
        request
        expect(response.body).to include("border-l-accent")
      end
    end

    context "when signed in as an operator" do
      let(:traits) { [:operator] }

      it "refuses" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
