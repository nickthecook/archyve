class RenameModelServerDefaultToActive < ActiveRecord::Migration[7.1]
  def change
    rename_column :model_servers, :default, :active
  end
end
