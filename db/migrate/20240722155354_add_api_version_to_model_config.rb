class AddApiVersionToModelConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :api_version, :string, default: nil, null: true
  end
end
