class AddDeletedAtToModelServer < ActiveRecord::Migration[7.1]
  def change
    add_column :model_servers, :deleted_at, :datetime
  end
end
