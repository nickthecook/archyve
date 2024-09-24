class AddErrorMessageToCollections < ActiveRecord::Migration[7.1]
  def change
    add_column :collections, :error_message, :string
  end
end
