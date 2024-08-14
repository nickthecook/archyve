class RenameCollectionGraphedToGraphEnabled < ActiveRecord::Migration[7.1]
  def change
    rename_column :collections, :graphed, :graph_enabled
  end
end
