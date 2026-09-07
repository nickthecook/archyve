class CreateCollectionUsers < ActiveRecord::Migration[8.1]
  def change
    # Who may do what in one collection. A row is a *grant*: its absence means
    # no access, not weak access, which is why there is no "everybody" default
    # and no nullable role.
    create_table :collection_users do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # Same ordered vocabulary as users.role — see Roleable. Combined by taking
      # the lower of the two, so the integers have to line up.
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    # One grant per person per collection; changing access edits the row.
    add_index :collection_users, [:collection_id, :user_id], unique: true
  end
end
