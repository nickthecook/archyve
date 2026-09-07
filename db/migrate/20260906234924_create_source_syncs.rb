class CreateSourceSyncs < ActiveRecord::Migration[8.1]
  def change
    create_table :source_syncs do |t|
      t.references :source, null: false, foreign_key: true

      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.text :error

      # The diff this scan produced. Counted synchronously while scanning, so
      # they are final the moment the scan ends — unlike per-document processing,
      # which continues afterwards and is read off the documents themselves.
      t.integer :found_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :unchanged_count, null: false, default: 0
      t.integer :removed_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0

      t.timestamps
    end

    # The source page wants "the latest run", and the sweeper wants "runs
    # still marked running" — both are this index.
    add_index :source_syncs, [:source_id, :started_at]
  end
end
