class AddAccessAndCollectionsToAgents < ActiveRecord::Migration[8.1]
  def change
    change_table :agents, bulk: true do |t|
      t.integer :access_mode, null: false, default: 0
      t.integer :collection_mode, null: false, default: 0
      t.references :creator, foreign_key: { to_table: :users, on_delete: :nullify }
    end

    create_table :agent_users do |t|
      t.references :agent, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :access, null: false, default: 0
      t.timestamps
      t.index [:agent_id, :user_id], unique: true
    end

    create_table :agent_collections do |t|
      t.references :agent, null: false, foreign_key: { on_delete: :cascade }
      t.references :collection, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
      t.index [:agent_id, :collection_id], unique: true
    end

    reversible do |direction|
      direction.up { execute "UPDATE agents SET collection_mode = 1 WHERE slug = 'admin_support'" }
    end
  end
end
