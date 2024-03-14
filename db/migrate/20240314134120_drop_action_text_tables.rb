class DropActionTextTables < ActiveRecord::Migration[7.1]
  def change
    drop_table :action_text_rich_texts, force: :cascade
    drop_table :active_storage_attachments, force: :cascade
    drop_table :active_storage_blobs, force: :cascade
    drop_table :active_storage_variant_records, force: :cascade
  end
end
