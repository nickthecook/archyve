class AddVisionToModelConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :vision, :boolean, default: false
  end
end
