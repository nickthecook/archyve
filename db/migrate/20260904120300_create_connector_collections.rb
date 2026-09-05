class CreateConnectorCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :connector_collections do |t|
      t.references :connector, null: false, foreign_key: true
      t.references :collection, null: false, foreign_key: true

      t.timestamps
    end

    add_index :connector_collections, [:connector_id, :collection_id], unique: true
  end
end
