class AddToolCallToSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :segments, :tool_call, :jsonb
  end
end
