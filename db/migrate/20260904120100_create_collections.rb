class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :collections, :slug, unique: true
  end
end
