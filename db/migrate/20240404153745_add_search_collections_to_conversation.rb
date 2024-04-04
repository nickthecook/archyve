class AddSearchCollectionsToConversation < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :search_collections, :boolean, default: true
  end
end
