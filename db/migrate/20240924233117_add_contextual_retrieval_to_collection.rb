class AddContextualRetrievalToCollection < ActiveRecord::Migration[7.1]
  def change
    add_column :collections, :contextual_retrieval_enabled, :boolean, default: false
  end
end
