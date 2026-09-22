require "rails_helper"

RSpec.describe "Sources", type: :request do
  let(:root) { Dir.mktmpdir("archyve-sources-request-spec") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "GET /sources" do
    context "with sources configured" do
      before do
        source = create(:folder_source, name: "Reference library", path: root)
        create(:source_user, :admin, source:, user: current_user)
      end

      it "lists them" do
        get sources_path
        expect(response.body).to include("Reference library")
      end
    end

    context "with no sources" do
      it "explains what to do" do
        get sources_path
        expect(response.body).to include("No sources yet")
      end
    end
  end

  describe "GET /sources/:id" do
    let(:source) { create(:folder_source, name: "Reference library", path: root) }

    before { create(:source_user, :admin, source:, user: current_user) }

    context "with a source that has never synced" do
      it "renders" do
        get source_path(source)
        expect(response).to have_http_status(:ok)
      end

      it "subscribes to the source's stream so scans appear without a refresh" do
        get source_path(source)
        expect(response.body).to include("turbo-cable-stream-source")
      end

      it "shows which file types are scanned" do
        get source_path(source)
        expect(response.body).to include(".pdf")
      end

      it "shows the size limit" do
        get source_path(source)
        expect(response.body).to include("100 MB")
      end
    end

    context "with a completed sync" do
      before do
        source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed",
          found_count: 4, created_count: 2, skipped_count: 1)
      end

      it "shows the scan's counts" do
        get source_path(source)
        expect(response.body).to include("skipped")
      end

      it "explains what each count means on hover" do
        get source_path(source)
        expect(response.body).to include("over the size limit")
      end

      # "Tombstone" is how the database thinks about it. To someone using
      # Archyve, the document was removed.
      it "does not leak the word tombstone into the UI" do
        get source_path(source)
        expect(response.body).not_to match(/tombston/i)
      end

      it "labels scan errors as errored" do
        get source_path(source)
        expect(response.body).to include("errored")
      end

      it "does not call them unreadable, since the scan never reads a file" do
        get source_path(source)
        expect(response.body).not_to include("unreadable")
      end
    end

    context "with a scan whose documents are still processing" do
      before do
        sync = source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current,
          status: "completed", found_count: 3, created_count: 3)
        3.times { create(:document, source: source, source_sync: sync, status: "pending") }
      end

      it "attributes the count to the documents, not to the scan" do
        get source_path(source)
        expect(response.body).to include("0 of 3 documents from this scan processed")
      end
    end

    # Moving files between directories in the source: three created, three
    # tombstoned. The tombstoned ones must not inflate the progress denominator.
    context "with a scan that both created and removed documents" do
      before do
        sync = source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current,
          status: "completed", found_count: 3, created_count: 3, removed_count: 3)
        3.times { create(:document, source: source, source_sync: sync, status: "processed") }
        3.times { create(:document, source: source, source_sync: sync, status: "removed") }
      end

      it "counts only the documents that entered the pipeline" do
        get source_path(source)
        expect(response.body).to include("3 of 3 documents from this scan processed")
      end

      it "does not count the tombstoned documents" do
        get source_path(source)
        expect(response.body).not_to include("of 6 documents")
      end
    end

    context "with a scan whose documents partly failed" do
      before do
        sync = source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed")
        create(:document, source: source, source_sync: sync, status: "processed")
        create(:document, source: source, source_sync: sync, status: "failed")
      end

      it "does not claim both are done" do
        get source_path(source)
        expect(response.body).to include("1 of 2 documents from this scan processed")
      end

      it "says how many failed" do
        get source_path(source)
        expect(response.body).to include("1 failed")
      end
    end

    context "with a failed sync" do
      before do
        source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "failed",
          error: "Errno::ENOENT: folder went away")
      end

      it "shows the error" do
        get source_path(source)
        expect(response.body).to include("folder went away")
      end
    end

    context "with a run that never reported back" do
      before { source.syncs.create!(started_at: 3.hours.ago, status: "running") }

      it "flags it as stalled" do
        get source_path(source)
        expect(response.body).to include("stalled")
      end
    end
  end

  describe "GET /sources/new" do
    context "with no type given" do
      it "offers the available source types" do
        get new_source_path
        expect(response.body).to include("Folder", "BookStack")
      end

      it "does not offer manual upload, which isn't created by hand" do
        get new_source_path
        expect(response.body).not_to include("Manual upload")
      end
    end

    context "with a type that exists but isn't user-creatable" do
      it "refuses it" do
        get new_source_path(type: "Sources::ManualUpload")
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with a known type" do
      it "renders the form" do
        get new_source_path(type: "Sources::Folder")
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a type that needs an endpoint" do
      let!(:endpoint) { create(:web_endpoint, name: "Handbook site") }

      before { get new_source_path(type: "Sources::Web") }

      it { expect(response).to have_http_status(:ok) }

      # Every type that names an endpoint_type gets the picker from the shared
      # form, so a new one cannot ship without a way to choose its server.
      it "offers the endpoints of that type" do
        expect(response.body).to include("Handbook site")
      end
    end

    context "with a type that needs an endpoint and none configured" do
      before { get new_source_path(type: "Sources::Web") }

      it "points at where one is added" do
        expect(response.body).to include("No Website endpoints yet")
      end
    end

    context "with a type that isn't a registered source" do
      it "refuses rather than instantiating it" do
        get new_source_path(type: "Kernel")
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST /sources" do
    let(:params) do
      { type: "Sources::Folder", source: { name: "Docs", path: root, sync_interval_minutes: "30" } }
    end

    context "with valid attributes" do
      it "creates the source" do
        expect { post sources_path, params: params }.to change { Source.count }.by(1)
      end

      it "stores the folder path" do
        post sources_path, params: params
        expect(Sources::Folder.last.path).to eq(root)
      end

      it "redirects to it" do
        post sources_path, params: params
        expect(response).to redirect_to(source_path(Source.last))
      end
    end

    # Per connector, because a folder of scans and a folder of exported
    # Markdown want opposite answers and can sit side by side in one archive.
    context "with OCR turned off" do
      let(:params) do
        { type: "Sources::Folder", source: { name: "Docs", path: root, ocr: "0" } }
      end

      it "stores the choice" do
        post sources_path, params: params
        expect(Source.last.ocr?).to be(false)
      end

      it "applies to the documents it produces" do
        post sources_path, params: params
        expect(create(:document, source: Source.last).ocr?).to be(false)
      end
    end

    context "with a path that isn't a directory" do
      let(:params) do
        { type: "Sources::Folder", source: { name: "Docs", path: "/no/such/folder" } }
      end

      it "does not create it" do
        expect { post sources_path, params: params }.not_to change { Source.count }
      end

      it "re-renders the form with the error" do
        post sources_path, params: params
        expect(response.body).to include("is not a directory Archyve can see")
      end
    end

    context "with collections selected" do
      let(:collection) { create(:collection) }
      let(:params) do
        {
          type: "Sources::Folder",
          source: { name: "Docs", path: root, collection_ids: [collection.id] }
        }
      end

      before { create(:collection_user, :operator, collection:, user: current_user) }

      it "feeds them" do
        post sources_path, params: params
        expect(Source.last.collections).to include(collection)
      end
    end
  end

  describe "the BookStack source" do
    let(:endpoint) { create(:bookstack_endpoint, name: "Work wiki", base_url: "https://wiki.test") }
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }

    # A whole wiki's worth of containers, which is what the picker draws from.
    # Stubbed on Http rather than on the source, so the endpoint's own auth
    # headers and base URL are exercised on the way through.
    def stub_wiki
      allow(Http).to receive(:connection).and_return(Faraday.new { |f| f.adapter(:test, stubs) })

      {
        "/api/shelves" => [{ "id" => 5, "name" => "Operations" }],
        "/api/books" => [{ "id" => 1, "name" => "Handbook", "slug" => "handbook" }],
        "/api/chapters" => [{ "id" => 3, "name" => "Joining", "book_id" => 1 }]
      }.each do |path, records|
        stubs.get("#{path}?count=500&offset=0") do
          [200, { "Content-Type" => "application/json" },
           { "data" => records, "total" => records.size }.to_json]
        end
      end
    end

    describe "GET /sources/new" do
      context "with a wiki that answers" do
        before do
          endpoint
          stub_wiki
          get new_source_path(type: "Sources::Bookstack")
        end

        it "offers the server" do
          expect(response.body).to include("Work wiki")
        end

        it "lists what can be synced, by name" do
          expect(response.body).to include("Operations", "Handbook", "Joining")
        end

        # Chapter names repeat across books; the book is what makes the choice.
        it "says which book a chapter is in" do
          expect(response.body).to include("Joining")
        end
      end

      # The picker is drawn from a live call, so it has to render something
      # when the token has been rotated or the wiki is down.
      context "with a wiki that refuses the token" do
        before do
          endpoint
          allow(Http).to receive(:connection).and_return(Faraday.new do |f|
            f.response :raise_error
            f.adapter(:test, stubs)
          end)
          stubs.get("/api/books?count=500&offset=0") { [401, {}, ""] }

          get new_source_path(type: "Sources::Bookstack")
        end

        it "still renders the form" do
          expect(response).to have_http_status(:ok)
        end

        it "says it couldn't read the wiki, and why" do
          expect(response.body).to include("Couldn&#39;t read Work wiki", "401")
        end
      end

      context "with no BookStack endpoints configured" do
        before { get new_source_path(type: "Sources::Bookstack") }

        it "points at where one is added" do
          expect(response.body).to include("No BookStack endpoints yet")
        end
      end
    end

    describe "POST /sources" do
      let(:params) do
        {
          type: "Sources::Bookstack",
          source: { name: "Wiki", endpoint_id: endpoint.id, selectors: ["", "book:1", "chapter:3"] }
        }
      end

      before { stub_wiki }

      it "creates it" do
        expect { post sources_path, params: params }.to change { Sources::Bookstack.count }.by(1)
      end

      # The picker submits "book:1"; what is stored is what was picked.
      it "stores what was picked, not its expansion" do
        post sources_path, params: params
        expect(Sources::Bookstack.last.selectors).to eq([{ "book" => 1 }, { "chapter" => 3 }])
      end

      it "points it at the endpoint" do
        post sources_path, params: params
        expect(Sources::Bookstack.last.endpoint).to eq(endpoint)
      end

      context "with nothing picked" do
        let(:params) do
          { type: "Sources::Bookstack", source: { name: "Wiki", endpoint_id: endpoint.id, selectors: [""] } }
        end

        # A source selecting nothing scans nothing, and everything it had
        # already produced would be tombstoned on the next pass.
        it "refuses, rather than creating a source that retires its own archive" do
          expect { post sources_path, params: params }.not_to change { Source.count }
        end
      end

      context "with an endpoint of the wrong type" do
        let(:other) { create(:folder_source) }
        let(:params) do
          {
            type: "Sources::Bookstack",
            source: { name: "Wiki", endpoint_id: Endpoint.create!(name: "Bare", type: "Endpoint").id,
                      selectors: ["book:1"] }
          }
        end

        it "refuses it" do
          expect { post sources_path, params: params }.not_to change { Source.count }
        end
      end
    end

    describe "PATCH /sources/:id" do
      let(:source) { create(:bookstack_source, endpoint:, selectors: [{ "book" => 1 }]) }

      before do
        create(:source_user, :admin, source:, user: current_user)
        stub_wiki
      end

      it "re-picks what to sync" do
        patch source_path(source), params: { source: { name: source.name, selectors: ["shelf:5"] } }
        expect(source.reload.selectors).to eq([{ "shelf" => 5 }])
      end

      # Every document is keyed by a page id that means something else on
      # another server, so repointing would silently re-key the lot.
      context "when a different server is submitted" do
        let(:elsewhere) { create(:bookstack_endpoint, name: "Other wiki") }

        it "ignores it" do
          patch source_path(source),
            params: { source: { name: source.name, endpoint_id: elsewhere.id, selectors: ["book:1"] } }
          expect(source.reload.endpoint).to eq(endpoint)
        end
      end
    end
  end

  describe "PATCH /sources/:id" do
    let(:source) { create(:folder_source, path: root) }

    before { create(:source_user, :admin, source:, user: current_user) }

    context "with a new interval" do
      it "saves it" do
        patch source_path(source),
          params: { source: { name: source.name, path: root, sync_interval_minutes: "5" } }
        expect(source.reload.sync_interval_minutes).to eq("5")
      end
    end

    context "when a collection is removed from the list" do
      let(:collection) { create(:collection) }
      let(:document) { create(:document, source: source, status: "processed") }

      before do
        create(:collection_user, :operator, collection:, user: current_user)
        source.collections << collection
        CollectionMembership.feed!(document: document, collection: collection)
      end

      it "retracts the memberships it had asserted" do
        patch source_path(source),
          params: { source: { name: source.name, path: root, collection_ids: [""] } }
        expect(CollectionMembership.find_by(document: document, collection: collection)).not_to be_active
      end
    end
  end

  describe "PATCH /sources/:id feed picker" do
    let(:source) { create(:folder_source, path: root) }

    before { create(:source_user, :admin, source:, user: current_user) }
    let(:mine) { create(:collection, name: "Mine") }
    let(:theirs) { create(:collection, name: "Theirs") }

    before { create(:collection_user, :operator, collection: mine, user: current_user) }

    # Feeding a collection decides what its readers see, so it belongs to the
    # collection rather than to whoever owns the source.
    context "when a collection they don't manage is submitted" do
      it "is not fed" do
        patch source_path(source),
          params: { source: { name: source.name, path: root, collection_ids: [theirs.id] } }
        expect(source.reload.collections).not_to include(theirs)
      end
    end

    # update_fed_collections diffs the full list and tombstones what's missing,
    # so submitting only the collections you can see would unfile another team's
    # documents without ever showing you they existed.
    context "when the source already feeds a collection they can't see" do
      let(:document) { create(:document, source:, status: "processed") }

      before do
        source.collections << theirs
        CollectionMembership.feed!(document:, collection: theirs)
      end

      it "leaves that feed in place" do
        patch source_path(source),
          params: { source: { name: source.name, path: root, collection_ids: [mine.id] } }
        expect(source.reload.collections).to include(theirs)
      end

      it "does not retract its memberships" do
        patch source_path(source),
          params: { source: { name: source.name, path: root, collection_ids: [mine.id] } }
        expect(CollectionMembership.find_by(document:, collection: theirs)).to be_active
      end

      it "still feeds the one they chose" do
        patch source_path(source),
          params: { source: { name: source.name, path: root, collection_ids: [mine.id] } }
        expect(source.reload.collections).to include(mine)
      end
    end

    context "when the picker is rendered" do
      before { theirs }

      it "offers only collections they manage" do
        get edit_source_path(source)
        expect(response.body).not_to include("Theirs")
      end
    end
  end

  describe "POST /sources/:id/sync" do
    context "with a syncable source" do
      let(:source) { create(:folder_source, path: root) }

      before { create(:source_user, :admin, source:, user: current_user) }

      it "enqueues a scan" do
        expect { post sync_source_path(source) }
          .to have_enqueued_job(Sources::SyncJob).with(source)
      end

      # Without this the page has nothing to watch until the run exists, and the
      # broadcast announcing it lands before the page has subscribed.
      it "records the request so the page keeps watching" do
        post sync_source_path(source)
        expect(source.reload).to be_sync_requested
      end
    end

    context "with a source that has nothing to scan" do
      let(:source) { create(:manual_upload_source) }

      before { create(:source_user, :admin, source:, user: current_user) }

      it "does not enqueue anything" do
        expect { post sync_source_path(source) }
          .not_to have_enqueued_job(Sources::SyncJob)
      end

      it "says why" do
        post sync_source_path(source)
        expect(flash[:alert]).to include("nothing to scan")
      end
    end
  end

  describe "DELETE /sources/:id" do
    let!(:source) { create(:folder_source, path: root) }

    before { create(:source_user, :admin, source:, user: current_user) }

    context "with documents produced by the source" do
      before { create(:document, source: source) }

      it "deletes them along with it" do
        expect { delete source_path(source) }.to change { Document.count }.by(-1)
      end
    end
  end
end
