require "rails_helper"

RSpec.describe "Document downloads", :unauthenticated, type: :request do
  subject(:request) { get download_document_path(document) }

  let(:document) { create(:document, :with_file) }

  before { sign_in(create(:user, *traits)) }

  # The point of the whole step: a reader who was pointed at a document can
  # fetch it, without being able to browse the archive to find others.
  context "when signed in as a plain user" do
    let(:traits) { [] }

    it "hands over the file" do
      request
      expect(response).to have_http_status(:ok)
    end

    it "sends it as an attachment" do
      request
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "still refuses the archive listing" do
      get documents_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "when signed in as an operator" do
    let(:traits) { [:operator] }

    it "hands over the file" do
      request
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the document has no file attached" do
    let(:traits) { [:operator] }
    let(:document) { create(:document) }

    it "is not found" do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
