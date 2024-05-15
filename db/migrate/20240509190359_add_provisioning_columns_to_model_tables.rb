class AddProvisioningColumnsToModelTables < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :provisioned, :boolean, default: false
    add_column :model_servers, :provisioned, :boolean, default: false

    add_column :model_configs, :enabled, :boolean, default: true
    add_column :model_servers, :enabled, :boolean, default: true
  end
end
