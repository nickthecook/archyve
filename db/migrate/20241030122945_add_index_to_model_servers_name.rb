class AddIndexToModelServersName < ActiveRecord::Migration[7.1]
  def change
    add_index :model_servers, :name, where: "deleted_at IS NULL", unique: true
  end
end
