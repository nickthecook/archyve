class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :source, null: false, foreign_key: true
      t.string :external_id, null: false        # stable id within the source
      t.string :source_version                    # etag / hash / revision for change detection
      t.string :title
      t.string :content_type
      t.jsonb :source_metadata, null: false, default: {}
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    # A source item is one document per source.
    add_index :documents, [:source_id, :external_id], unique: true
    add_index :documents, :status
  end
end
