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

      it "shows the switch in both states" do
        request
        expect(response.body).to include('aria-checked="false"', 'aria-checked="true"')
      end

      # A style guide that mutates the app when poked is worse than no style
      # guide: these switches are outside any form and must stay that way.
      it "renders switches that cannot submit anything" do
        request
        expect(response.body).not_to include(settings_preferences_path)
      end
    end

    context "when signed in as a curator" do
      let(:traits) { [:curator] }

      it "refuses" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
