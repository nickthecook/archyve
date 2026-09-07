class AddSourceSyncToDocuments < ActiveRecord::Migration[8.1]
  def change
    # The sync run that last created or updated this document. Attribution, not
    # ownership: it is how a run reports its own processing progress
    # (documents.where(source_sync_id: run.id).group(:status)) without any
    # cross-job counter to keep in step. Nullified rather than cascaded when a
    # run is pruned — the document outlives the record of how it arrived.
    add_reference :documents, :source_sync, foreign_key: { on_delete: :nullify }, index: true
  end
end
