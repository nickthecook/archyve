class AddDirectionAndCallerToApiCalls < ActiveRecord::Migration[8.1]
  def change
    add_column :api_calls, :incoming, :boolean, null: false, default: false
    add_reference :api_calls, :user, foreign_key: { on_delete: :nullify }
    add_reference :api_calls, :api_key, foreign_key: { on_delete: :nullify }
  end
end
