class AddClientIdToClient < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :client_id, :string, null: false

    add_index :clients, :client_id, unique: true
    add_index :clients, [:user_id, :name], unique: true
  end
end
