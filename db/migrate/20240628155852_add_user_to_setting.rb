class AddUserToSetting < ActiveRecord::Migration[7.1]
  def change
    add_reference :settings, :user, null: true, foreign_key: true
  end
end
