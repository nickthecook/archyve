class RemoveModelServerFromModelConfig < ActiveRecord::Migration[7.1]
  def change
    remove_column :model_configs, :model_server_id
  end
end
