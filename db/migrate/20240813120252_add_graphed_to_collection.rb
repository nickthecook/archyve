class AddGraphedToCollection < ActiveRecord::Migration[7.1]
  def change
    add_column :collections, :graphed, :boolean, default: false
  end
end
