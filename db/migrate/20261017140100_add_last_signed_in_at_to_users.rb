# Sessions are swept once they expire, so the newest surviving one is the best
# backfill there is. Anyone without one reads as not having signed in lately,
# which is true as far as this table can tell.
class AddLastSignedInAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :last_signed_in_at, :datetime
    execute <<~SQL
      UPDATE users SET last_signed_in_at = latest.created_at
      FROM (SELECT user_id, MAX(created_at) AS created_at FROM sessions GROUP BY user_id) latest
      WHERE latest.user_id = users.id
    SQL
  end

  def down
    remove_column :users, :last_signed_in_at
  end
end
