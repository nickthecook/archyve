class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.timestamps
      t.index :name, unique: true
    end

    create_table :group_users do |t|
      t.references :group, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
      t.index [:group_id, :user_id], unique: true
    end

    create_table :collection_groups do |t|
      t.references :collection, null: false, foreign_key: { on_delete: :cascade }
      t.references :group, null: false, foreign_key: { on_delete: :cascade }
      t.integer :access, null: false, default: 0
      t.timestamps
      t.index [:collection_id, :group_id], unique: true
    end

    create_table :source_groups do |t|
      t.references :source, null: false, foreign_key: { on_delete: :cascade }
      t.references :group, null: false, foreign_key: { on_delete: :cascade }
      t.integer :access, null: false, default: 0
      t.timestamps
      t.index [:source_id, :group_id], unique: true
    end
  end
end
