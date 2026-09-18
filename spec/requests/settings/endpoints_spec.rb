require "rails_helper"

RSpec.describe "Settings::Endpoints", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "GET /settings/endpoints" do
    subject(:request) { get settings_endpoints_path }

    context "with none configured" do
      it "explains what that costs" do
        request
        expect(response.body).to include("sources that pull from a remote system like a wiki")
      end
    end

    context "with an endpoint" do
      before { create(:bookstack_endpoint, name: "Work wiki") }

      it "lists it" do
        request
        expect(response.body).to include("Work wiki")
      end

      # Grey, not red: nobody having tried it yet isn't a fault.
      it "says it has never been used" do
        request
        expect(response.body).to include("never used")
      end
    end

    context "when an operator asks" do
      let(:operator) { create(:user, :operator) }

      before { sign_in(operator) }

      it "is refused — credentials are IT's" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /settings/endpoints/new" do
    # Landing on a BookStack form you never chose is jolting, so the picker
    # stands even while there is one type.
    context "without a type" do
      it "offers the choice" do
        get new_settings_endpoint_path
        expect(response.body).to include("Add an endpoint")
        expect(response.body).to include("BookStack")
      end
    end

    context "with a type" do
      it "renders that type's form" do
        get new_settings_endpoint_path(type: "Endpoints::Bookstack")
        expect(response.body).to include("Token ID")
        expect(response.body).to include("Token secret")
      end
    end

    context "with a type nobody registered" do
      it "refuses rather than constantizing it" do
        get new_settings_endpoint_path(type: "User")
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST /settings/endpoints" do
    subject(:request) do
      post settings_endpoints_path, params: { type: "Endpoints::Bookstack", endpoint: attributes }
    end

    let(:attributes) do
      { name: "Work wiki", base_url: "https://wiki.test", token_id: "abc", token_secret: "xyz" }
    end

    context "with everything filled in" do
      it "creates it" do
        expect { request }.to change(Endpoint, :count).by(1)
      end

      it "stores the secret out of reach of SQL" do
        request
        stored = Endpoint.connection.select_value("SELECT credentials FROM endpoints")
        expect(stored).not_to include("xyz")
      end
    end

    context "with the secret missing" do
      let(:attributes) { super().merge(token_secret: "") }

      it "is rejected" do
        expect { request }.not_to change(Endpoint, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /settings/endpoints/:id" do
    let(:endpoint) { create(:bookstack_endpoint, token_secret: "original") }

    # The form renders the secret as an empty field; submitting it to change
    # something else must not wipe the token every source depends on.
    context "when the secret is left blank" do
      it "keeps the stored one" do
        patch settings_endpoint_path(endpoint), params: { endpoint: { name: "Renamed", token_secret: "" } }

        expect(endpoint.reload.name).to eq("Renamed")
        expect(endpoint.token_secret).to eq("original")
      end
    end
  end

  describe "DELETE /settings/endpoints/:id" do
    let!(:endpoint) { create(:bookstack_endpoint) }

    context "when nothing points at it" do
      it "removes it" do
        expect { delete settings_endpoint_path(endpoint) }.to change(Endpoint, :count).by(-1)
      end
    end

    context "when a source still points at it" do
      before { create(:folder_source, endpoint: endpoint) }

      it "refuses and says why" do
        expect { delete settings_endpoint_path(endpoint) }.not_to change(Endpoint, :count)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /settings/endpoints/:id/access" do
    let(:endpoint) { create(:bookstack_endpoint, name: "Work wiki") }

    context "when the server answers" do
      before { allow_any_instance_of(Endpoints::Bookstack).to receive(:access!).and_return(true) }

      it "says so in as many words" do
        post access_settings_endpoint_path(endpoint)
        expect(flash[:notice]).to include("Connected to")
      end

      # The flash is gone on the next navigation; the panel is what an admin
      # sees every visit after, so it has to carry the verdict too.
      it "leaves the page saying the endpoint is working" do
        post access_settings_endpoint_path(endpoint)
        follow_redirect!
        expect(response.body).to include("working")
      end
    end

    context "when the token is rejected" do
      before do
        allow_any_instance_of(Endpoints::Bookstack).to receive(:access!)
          .and_raise(Faraday::UnauthorizedError, "401")
      end

      it "lands back on the page with the reason" do
        post access_settings_endpoint_path(endpoint)
        follow_redirect!
        expect(response.body).to include("401")
      end
    end
  end
end
