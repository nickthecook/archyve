class RemoveModelConfigDefault < ActiveRecord::Migration[7.1]
  def change
    remove_column :model_configs, :default
  end
end
