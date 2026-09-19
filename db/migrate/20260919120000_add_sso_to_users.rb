class AddSsoToUsers < ActiveRecord::Migration[8.1]
  def change
    # The IdP's permanent identifier for the person. Email is what they type and
    # what changes; `sub` is what Keycloak promises never will, so identity is
    # keyed here and email is refreshed from the claim on every sign-in.
    add_column :users, :sso_subject, :string
    # A `sub` is only unique within its issuer, so a second realm later would
    # otherwise be able to collide with the first.
    add_column :users, :sso_issuer, :string

    add_index :users, :sso_subject, unique: true
  end
end
