class CreateEndpoints < ActiveRecord::Migration[8.1]
  def change
    # A server Archyve pulls documents from, plus the credentials for it. An STI
    # `type` naming the system, a jsonb `config` the subclass reads through
    # store_accessor, and secrets in a column of their own.
    create_table :endpoints do |t|
      t.string :name, null: false
      t.string :type, null: false

      # Everything about the server that isn't a secret: base URL, a token *id*,
      # a region. Readable in SQL on purpose — an admin list wants to show which
      # host a row points at without decrypting anything.
      t.jsonb :config, default: {}, null: false

      # Secrets, as a JSON object so each endpoint type can hold whatever shape
      # its auth takes — a password, a bearer token, an access/secret key pair.
      # `text`, not jsonb: encrypting it forfeits the querying and indexing that
      # are jsonb's whole point.
      t.text :credentials

      # The last time Archyve used this endpoint, and what went wrong if it
      # didn't work. A byproduct of syncing rather than a scheduled probe.
      t.datetime :accessed_at
      t.string :access_error

      t.timestamps
    end

    add_index :endpoints, :type
    # Endpoints are picked by name when configuring a source, and two rows both
    # called "BookStack" would be indistinguishable in that list.
    add_index :endpoints, :name, unique: true
  end
end
