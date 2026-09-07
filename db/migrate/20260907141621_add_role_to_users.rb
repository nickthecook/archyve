class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    # Integer rather than string so the values are *ordered*: the whole point of
    # the role is to be a ceiling, and `min(global_role, object_role)` only works
    # if greater means more. Defaults to the least privileged, so an account
    # created without a stated role can't accidentally be powerful.
    add_column :users, :role, :integer, null: false, default: 0
    add_index :users, :role
  end
end
