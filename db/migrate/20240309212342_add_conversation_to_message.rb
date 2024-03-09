class AddConversationToMessage < ActiveRecord::Migration[7.1]
  def change
    add_reference :messages, :conversation, null: false, foreign_key: true
  end
end
