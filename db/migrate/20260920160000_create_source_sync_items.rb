class CreateSourceSyncItems < ActiveRecord::Migration[8.1]
  def change
    # Per-item outcomes that outlive a run's counters. Never a complete
    # enumeration of what a run saw — only the items worth remembering, which
    # today means the ones that failed. See docs/todo.md, "Surfacing sync
    # failures"; phase 4 of "The web source" adds the crawler's use of the same
    # table as a frontier, and the columns that go with it.
    create_table :source_sync_items do |t|
      t.references :source_sync, null: false, foreign_key: true
      t.string :external_id, null: false

      # Null means discovered but not yet attempted, which only a source that
      # enumerates through this table can produce.
      t.string :disposition
      t.jsonb :detail, default: {}, null: false

      t.timestamps
    end

    # The dedup a discovering source relies on: insert and let the index absorb
    # the rediscoveries, rather than checking first.
    add_index :source_sync_items, [:source_sync_id, :external_id], unique: true
    add_index :source_sync_items, [:source_sync_id, :disposition]
  end
end
