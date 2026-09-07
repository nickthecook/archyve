require "rails_helper"

RSpec.describe "Settings::Connectors", type: :request do
  let(:root) { Dir.mktmpdir("archyve-connectors-request-spec") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "GET /settings/connectors" do
    context "with connectors configured" do
      before { create(:folder_connector, name: "Reference library", path: root) }

      it "lists them" do
        get settings_connectors_path
        expect(response.body).to include("Reference library")
      end
    end

    context "with no connectors" do
      it "explains what to do" do
        get settings_connectors_path
        expect(response.body).to include("No connectors yet")
      end
    end
  end

  describe "GET /settings/connectors/:id" do
    let(:connector) { create(:folder_connector, name: "Reference library", path: root) }

    context "with a connector that has never synced" do
      it "renders" do
        get settings_connector_path(connector)
        expect(response).to have_http_status(:ok)
      end

      it "subscribes to the connector's stream so scans appear without a refresh" do
        get settings_connector_path(connector)
        expect(response.body).to include("turbo-cable-stream-source")
      end

      it "shows which file types are scanned" do
        get settings_connector_path(connector)
        expect(response.body).to include(".pdf")
      end

      it "shows the size limit" do
        get settings_connector_path(connector)
        expect(response.body).to include("100 MB")
      end
    end

    context "with a completed sync" do
      before do
        connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed",
          found_count: 4, created_count: 2, skipped_count: 1)
      end

      it "shows the scan's counts" do
        get settings_connector_path(connector)
        expect(response.body).to include("skipped")
      end

      it "explains what each count means on hover" do
        get settings_connector_path(connector)
        expect(response.body).to include("over the size limit")
      end

      # "Tombstone" is how the database thinks about it. To someone using
      # Archyve, the document was removed.
      it "does not leak the word tombstone into the UI" do
        get settings_connector_path(connector)
        expect(response.body).not_to match(/tombston/i)
      end

      it "labels scan errors as errored" do
        get settings_connector_path(connector)
        expect(response.body).to include("errored")
      end

      it "does not call them unreadable, since the scan never reads a file" do
        get settings_connector_path(connector)
        expect(response.body).not_to include("unreadable")
      end
    end

    context "with a scan whose documents are still processing" do
      before do
        sync = connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current,
          status: "completed", found_count: 3, created_count: 3)
        3.times { create(:document, connector: connector, connector_sync: sync, status: "pending") }
      end

      it "attributes the count to the documents, not to the scan" do
        get settings_connector_path(connector)
        expect(response.body).to include("0 of 3 documents from this scan processed")
      end
    end

    # Moving files between directories in the source: three created, three
    # tombstoned. The tombstoned ones must not inflate the progress denominator.
    context "with a scan that both created and removed documents" do
      before do
        sync = connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current,
          status: "completed", found_count: 3, created_count: 3, removed_count: 3)
        3.times { create(:document, connector: connector, connector_sync: sync, status: "processed") }
        3.times { create(:document, connector: connector, connector_sync: sync, status: "removed") }
      end

      it "counts only the documents that entered the pipeline" do
        get settings_connector_path(connector)
        expect(response.body).to include("3 of 3 documents from this scan processed")
      end

      it "does not count the tombstoned documents" do
        get settings_connector_path(connector)
        expect(response.body).not_to include("of 6 documents")
      end
    end

    context "with a scan whose documents partly failed" do
      before do
        sync = connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed")
        create(:document, connector: connector, connector_sync: sync, status: "processed")
        create(:document, connector: connector, connector_sync: sync, status: "failed")
      end

      it "does not claim both are done" do
        get settings_connector_path(connector)
        expect(response.body).to include("1 of 2 documents from this scan processed")
      end

      it "says how many failed" do
        get settings_connector_path(connector)
        expect(response.body).to include("1 failed")
      end
    end

    context "with a failed sync" do
      before do
        connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "failed",
          error: "Errno::ENOENT: folder went away")
      end

      it "shows the error" do
        get settings_connector_path(connector)
        expect(response.body).to include("folder went away")
      end
    end

    context "with a run that never reported back" do
      before { connector.syncs.create!(started_at: 3.hours.ago, status: "running") }

      it "flags it as stalled" do
        get settings_connector_path(connector)
        expect(response.body).to include("stalled")
      end
    end
  end

  describe "GET /settings/connectors/new" do
    context "with no type given" do
      it "offers the available connector types" do
        get new_settings_connector_path
        expect(response.body).to include("Folder")
      end

      it "does not offer manual upload, which isn't created by hand" do
        get new_settings_connector_path
        expect(response.body).not_to include("Manual upload")
      end
    end

    context "with a type that exists but isn't user-creatable" do
      it "refuses it" do
        get new_settings_connector_path(type: "Connectors::ManualUpload")
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with a known type" do
      it "renders the form" do
        get new_settings_connector_path(type: "Connectors::Folder")
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a type that isn't a registered connector" do
      it "refuses rather than instantiating it" do
        get new_settings_connector_path(type: "Kernel")
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST /settings/connectors" do
    let(:params) do
      { type: "Connectors::Folder", connector: { name: "Docs", path: root, sync_interval_minutes: "30" } }
    end

    context "with valid attributes" do
      it "creates the connector" do
        expect { post settings_connectors_path, params: params }.to change { Connector.count }.by(1)
      end

      it "stores the folder path" do
        post settings_connectors_path, params: params
        expect(Connectors::Folder.last.path).to eq(root)
      end

      it "redirects to it" do
        post settings_connectors_path, params: params
        expect(response).to redirect_to(settings_connector_path(Connector.last))
      end
    end

    context "with a path that isn't a directory" do
      let(:params) do
        { type: "Connectors::Folder", connector: { name: "Docs", path: "/no/such/folder" } }
      end

      it "does not create it" do
        expect { post settings_connectors_path, params: params }.not_to change { Connector.count }
      end

      it "re-renders the form with the error" do
        post settings_connectors_path, params: params
        expect(response.body).to include("is not a directory Archyve can see")
      end
    end

    context "with collections selected" do
      let(:collection) { create(:collection) }
      let(:params) do
        {
          type: "Connectors::Folder",
          connector: { name: "Docs", path: root, collection_ids: [collection.id] }
        }
      end

      it "feeds them" do
        post settings_connectors_path, params: params
        expect(Connector.last.collections).to include(collection)
      end
    end
  end

  describe "PATCH /settings/connectors/:id" do
    let(:connector) { create(:folder_connector, path: root) }

    context "with a new interval" do
      it "saves it" do
        patch settings_connector_path(connector),
          params: { connector: { name: connector.name, path: root, sync_interval_minutes: "5" } }
        expect(connector.reload.sync_interval_minutes).to eq("5")
      end
    end

    context "when a collection is removed from the list" do
      let(:collection) { create(:collection) }
      let(:document) { create(:document, connector: connector, status: "processed") }

      before do
        connector.collections << collection
        CollectionMembership.feed!(document: document, collection: collection)
      end

      it "retracts the memberships it had asserted" do
        patch settings_connector_path(connector),
          params: { connector: { name: connector.name, path: root, collection_ids: [""] } }
        expect(CollectionMembership.find_by(document: document, collection: collection)).not_to be_active
      end
    end
  end

  describe "POST /settings/connectors/:id/sync" do
    context "with a syncable connector" do
      let(:connector) { create(:folder_connector, path: root) }

      it "enqueues a scan" do
        expect { post sync_settings_connector_path(connector) }
          .to have_enqueued_job(Connectors::SyncJob).with(connector)
      end
    end

    context "with a connector that has nothing to scan" do
      let(:connector) { create(:manual_upload_connector) }

      it "does not enqueue anything" do
        expect { post sync_settings_connector_path(connector) }
          .not_to have_enqueued_job(Connectors::SyncJob)
      end

      it "says why" do
        post sync_settings_connector_path(connector)
        expect(flash[:alert]).to include("nothing to scan")
      end
    end
  end

  describe "DELETE /settings/connectors/:id" do
    let!(:connector) { create(:folder_connector, path: root) }

    context "with documents produced by the connector" do
      before { create(:document, connector: connector) }

      it "deletes them along with it" do
        expect { delete settings_connector_path(connector) }.to change { Document.count }.by(-1)
      end
    end
  end
end
