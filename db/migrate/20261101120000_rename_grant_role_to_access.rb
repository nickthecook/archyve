class RenameGrantRoleToAccess < ActiveRecord::Migration[8.1]
  def change
    rename_column :collection_users, :role, :access
    rename_column :source_users, :role, :access
  end
end
