class AddModelServerIdToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :model_server_id, :integer
  end
end
