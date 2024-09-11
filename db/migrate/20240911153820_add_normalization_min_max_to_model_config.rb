class AddNormalizationMinMaxToModelConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :distance_min, :float
    add_column :model_configs, :distance_max, :float
  end
end
