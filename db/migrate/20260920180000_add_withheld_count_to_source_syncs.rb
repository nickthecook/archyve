class AddWithheldCountToSourceSyncs < ActiveRecord::Migration[8.1]
  def change
    # Documents the run declined to tombstone because it could not tell whether
    # they were gone or merely hidden behind something that failed. Recorded
    # rather than derived: the rows that justified it are reaped, and a scan
    # that quietly stops pruning needs to say so.
    add_column :source_syncs, :withheld_count, :integer, default: 0, null: false
  end
end
