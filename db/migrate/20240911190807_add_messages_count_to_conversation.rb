class AddMessagesCountToConversation < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :messages_count, :integer

    Conversation.reset_column_information
    Conversation.all.each do |c|
      c.update(messages_count: c.messages.length)
    end
  end
end
