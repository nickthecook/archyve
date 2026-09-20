class AddResumableScanSupport < ActiveRecord::Migration[8.1]
  def up
    # Distinct from `source_sync_id`, which means "the run that created, updated
    # or retired this document" and is what SourceSync#documents hangs off. This
    # one means "the run that last *saw* it", which a scan spanning several jobs
    # needs in order to tombstone without holding every external_id in memory.
    add_reference :documents, :last_seen_sync, foreign_key: { to_table: :source_syncs, on_delete: :nullify }
    add_index :documents, [:source_id, :last_seen_sync_id]

    # Deliberately not backfilled. A document with no stamp reads as unseen, and
    # the next scan stamps everything actually present before any tombstoning
    # happens — so the correct set is reached on the first run either way.

    add_column :source_syncs, :last_progress_at, :datetime

    execute <<~SQL.squish
      UPDATE source_syncs SET last_progress_at = COALESCE(finished_at, started_at)
    SQL
  end

  def down
    remove_column :source_syncs, :last_progress_at
    remove_index :documents, [:source_id, :last_seen_sync_id]
    remove_reference :documents, :last_seen_sync, foreign_key: { to_table: :source_syncs }
  end
end
