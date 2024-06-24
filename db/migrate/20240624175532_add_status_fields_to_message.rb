class AddStatusFieldsToMessage < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :statistics, :jsonb
    add_column :messages, :error, :jsonb
  end
end
