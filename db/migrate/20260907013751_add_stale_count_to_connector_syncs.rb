class AddStaleCountToConnectorSyncs < ActiveRecord::Migration[8.1]
  def change
    # Documents the archive holds whose source has since changed into something
    # this connector can't ingest — currently, grown past the size limit. Split
    # out from `skipped_count` (which the source has but the archive never took)
    # because the two read the same in a total and mean opposite things: a skip
    # is a file we don't have, a stale is a document we do have and can no longer
    # trust. Unlike a failure, it does not resolve itself on the next scan.
    add_column :connector_syncs, :stale_count, :integer, null: false, default: 0
  end
end
