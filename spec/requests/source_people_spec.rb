require "rails_helper"

RSpec.describe "Source people", :unauthenticated, type: :request do
  let(:root) { Dir.mktmpdir("archyve-source-people-spec") }
  let(:source) { create(:folder_source, name: "Reference library", path: root) }
  let(:curator) { create(:user, :curator) }
  let(:admin) { create(:user, :admin) }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "GET /sources/:id/people" do
    subject(:request) { get source_people_path(source) }

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      # The collection People screen renders the same panel, and a source and a
      # collection can have confusingly similar names.
      it "says which kind of thing it is managing" do
        request
        expect(response.body).to include("Source")
      end

      # Chat-only accounts can't reach /sources at all, so a grant would be
      # offering them nothing.
      it "does not offer chat-only accounts as candidates" do
        reader = create(:user, email_address: "reader@example.com")
        request
        expect(response.body).not_to include(reader.email_address)
      end
    end

    context "when signed in as a curator who manages the source" do
      before do
        sign_in(curator)
        create(:source_user, :manager, source:, user: curator)
      end

      it "is refused" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /sources/:id/people" do
    subject(:request) { post source_people_path(source), params: { user_id: target.id, access: } }

    let(:target) { create(:user, :curator) }
    let(:access) { "editor" }

    before { sign_in(admin) }

    it "grants access" do
      expect { request }.to change { source.source_users.count }.by(1)
    end

    # The grant that lets someone attach this source to their own collection
    # without touching its settings.
    context "when the grant is `accessor`" do
      let(:access) { "accessor" }

      it "does not make the source manageable by them" do
        request
        expect(Source.manageable_by(target)).not_to include(source)
      end

      it "does make it attachable by them" do
        request
        expect(Source.attachable_by(target)).to include(source)
      end
    end
  end

  describe "PATCH /sources/:id/people/:id" do
    subject(:request) { patch source_person_path(source, grant), params: { access: "accessor" } }

    let(:grant) { create(:source_user, source:, user: curator) }

    before { sign_in(admin) }

    it "changes the grant" do
      request
      expect(grant.reload.access).to eq("accessor")
    end
  end

  describe "the sources list" do
    subject(:request) { get sources_path }

    before { sign_in(curator) }

    context "when the curator holds no grant" do
      before { source }

      it "does not show the source" do
        request
        expect(response.body).not_to include("Reference library")
      end
    end

    context "when the curator holds a grant" do
      before { create(:source_user, source:, user: curator) }

      it "shows the source" do
        request
        expect(response.body).to include("Reference library")
      end
    end
  end

  describe "creating a source" do
    subject(:request) do
      post sources_path, params: { type: "Sources::Folder", source: { name: "New Shelf", path: root } }
    end

    before { sign_in(curator) }

    # Otherwise a curator can't manage the source they just added.
    it "makes the creator its manager" do
      request
      expect(curator.grant_on(Source.find_by(name: "New Shelf"))).to eq(:manager)
    end
  end
end
