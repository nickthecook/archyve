class AddIndexToClientName < ActiveRecord::Migration[7.1]
  def change
    add_index :clients, [:name], unique: true
  end
end
