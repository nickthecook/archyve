class CreateSourceCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :source_collections do |t|
      t.references :source, null: false, foreign_key: true
      t.references :collection, null: false, foreign_key: true

      t.timestamps
    end

    add_index :source_collections, [:source_id, :collection_id], unique: true
  end
end
