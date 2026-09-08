require "rails_helper"

RSpec.describe "Source people", :unauthenticated, type: :request do
  let(:root) { Dir.mktmpdir("archyve-source-people-spec") }
  let(:source) { create(:folder_source, name: "Reference library", path: root) }
  let(:operator) { create(:user, :operator) }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "GET /sources/:id/people" do
    subject(:request) { get source_people_path(source) }

    context "when the operator administers the source" do
      before do
        sign_in(operator)
        create(:source_user, :admin, source:, user: operator)
      end

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

    # Configuring a source and delegating it are different things.
    context "when the operator can only configure the source" do
      before do
        sign_in(operator)
        create(:source_user, source:, user: operator)
      end

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when they own the source" do
      let(:source) { create(:source, name: "Uploads", user: operator) }

      before { sign_in(operator) }

      it "renders, because owning a source is administering it" do
        request
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /sources/:id/people" do
    subject(:request) { post source_people_path(source), params: { user_id: target.id, role: } }

    let(:target) { create(:user, :operator) }
    let(:role) { "operator" }

    before do
      sign_in(operator)
      create(:source_user, :admin, source:, user: operator)
    end

    it "grants access" do
      expect { request }.to change { source.source_users.count }.by(1)
    end

    # The grant that lets someone attach this source to their own collection
    # without touching its settings.
    context "when the role is `user`" do
      let(:role) { "user" }

      it "grants it" do
        expect { request }.to change { source.source_users.count }.by(1)
      end

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

  describe "the sources list" do
    subject(:request) { get sources_path }

    before { sign_in(operator) }

    context "when the operator holds no grant" do
      before { source }

      it "does not show the source" do
        request
        expect(response.body).not_to include("Reference library")
      end
    end

    context "when the operator holds a grant" do
      before { create(:source_user, source:, user: operator) }

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

    before { sign_in(operator) }

    # Otherwise an operator can't manage the source they just added.
    it "makes the creator its admin" do
      request
      expect(operator.role_on(Source.find_by(name: "New Shelf"))).to eq(:admin)
    end
  end
end
