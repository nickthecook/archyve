class CreateCollectionMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_memberships do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.string :origin, null: false             # feed | manual
      t.datetime :removed_at                      # tombstone: set = removed, survives re-sync

      t.timestamps
    end

    add_index :collection_memberships, [:collection_id, :document_id], unique: true
    # Fast lookup of a collection's active members (for filtered ANN).
    add_index :collection_memberships, [:collection_id, :removed_at]
  end
end
