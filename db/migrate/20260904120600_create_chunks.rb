class CreateChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :position, null: false          # order within the document
      t.text :content, null: false
      t.jsonb :structure, null: false, default: {}  # heading path, page, etc. (from Docling)

      t.timestamps
    end

    add_index :chunks, [:document_id, :position], unique: true
  end
end
