class AddProvisioningToInference < ActiveRecord::Migration[8.1]
  def change
    add_column :inference_servers, :provisioned, :boolean, default: false, null: false
    add_column :inference_servers, :enabled, :boolean, default: true, null: false
    add_column :inference_models, :provisioned, :boolean, default: false, null: false
  end
end
