class AllowUsersWithoutPasswords < ActiveRecord::Migration[8.1]
  def change
    # An SSO-provisioned user has no password at all, and NULL says so honestly.
    # It also means the password form can never authenticate them, which is what
    # stops the Keycloak group check from being bypassable from /session/new.
    change_column_null :users, :password_digest, true
  end
end
