class AddStateToCollection < ActiveRecord::Migration[7.1]
  def change
    add_column :collections, :state, :integer, default: 0
  end
end
