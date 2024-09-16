class AddDirectionToApiCall < ActiveRecord::Migration[7.1]
  def change
    add_column :api_calls, :incoming, :boolean, default: false
  end
end
