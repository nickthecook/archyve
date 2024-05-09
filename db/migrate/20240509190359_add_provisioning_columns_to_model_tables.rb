class AddProvisioningColumnsToModelTables < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :provisioned, :boolean, default: false, if_not_exists: true
    add_column :model_servers, :provisioned, :boolean, default: false, if_not_exists: true

    add_column :model_configs, :enabled, :boolean, default: true, if_not_exists: true
    add_column :model_servers, :enabled, :boolean, default: true, if_not_exists: true
  end
end
