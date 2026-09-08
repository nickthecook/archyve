class CreateSourceUsers < ActiveRecord::Migration[8.1]
  def change
    # Who may manage one source. Same shape as collection_users, with one
    # difference: there is no reader role here. Seeing that a source exists is
    # implied by seeing a collection it feeds, so a `user` grant would mean
    # nothing — SourceUser validates it away.
    create_table :source_users do |t|
      t.references :source, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, null: false, default: 1 # operator; see Roleable

      t.timestamps
    end

    add_index :source_users, [:source_id, :user_id], unique: true
  end
end
