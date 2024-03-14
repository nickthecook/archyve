class DropUserFromMessages < ActiveRecord::Migration[7.1]
  def change
    remove_column :messages, :user_id
  end
end
