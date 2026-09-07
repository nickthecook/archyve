class AddSkippedCountToSourceSyncs < ActiveRecord::Migration[8.1]
  def change
    # Items the source still has but that we declined to ingest — currently
    # files over the size limit. Counted separately from `failed_count` (items we
    # could not read) because a skip is a decision, not an error, and separately
    # from `removed_count` because a skipped item is emphatically still there.
    add_column :source_syncs, :skipped_count, :integer, null: false, default: 0
  end
end
