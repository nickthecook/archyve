class CascadeConversationDeletes < ActiveRecord::Migration[8.1]
  def up
    replace_foreign_key :messages, :conversations, on_delete: :cascade
    replace_foreign_key :segments, :messages, on_delete: :cascade
    replace_foreign_key :hits, :segments, on_delete: :cascade
  end

  def down
    replace_foreign_key :messages, :conversations
    replace_foreign_key :segments, :messages
    replace_foreign_key :hits, :segments
  end

  private

  def replace_foreign_key(from, to, **options)
    remove_foreign_key from, to
    add_foreign_key from, to, **options
  end
end
