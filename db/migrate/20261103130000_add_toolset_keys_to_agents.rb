class AddToolsetKeysToAgents < ActiveRecord::Migration[8.1]
  def up
    add_column :agents, :toolset_keys, :string, array: true, null: false, default: []
    execute "UPDATE agents SET toolset_keys = '{archive}' WHERE slug = 'archivist'"
  end

  def down
    remove_column :agents, :toolset_keys
  end
end
