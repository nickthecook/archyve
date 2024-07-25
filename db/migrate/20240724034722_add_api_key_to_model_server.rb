class AddApiKeyToModelServer < ActiveRecord::Migration[7.1]
  def change
    add_column :model_servers, :api_key, :string, default: nil, null: true
  end
end
