class AddSourceToConversation < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :source, :integer
  end
end
