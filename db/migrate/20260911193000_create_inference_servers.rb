class CreateInferenceServers < ActiveRecord::Migration[8.1]
  def change
    # Where Archyve sends prompts, and with what credentials. Shaped on
    # `sources`: an STI `type` naming the provider, plus a jsonb `config` the
    # subclass reads through store_accessor. One row per endpoint, so a model
    # never carries its own copy of a URL.
    create_table :inference_servers do |t|
      t.string :name, null: false
      t.string :type, null: false
      t.jsonb :config, default: {}, null: false

      # Secrets get their own column rather than a key inside `config`.
      # docs/todo.md spells out why at length: encrypting a jsonb that anything
      # reads in SQL fails *silently* — the extraction just returns ciphertext
      # while store_accessor keeps working in Ruby, so it all still looks fine.
      # Nothing reads this config in SQL today; keeping the two separated means
      # nothing has to remember the rule the day something does.
      t.text :api_key

      # The last connection check. Kept on the server rather than in a run table
      # like source_syncs: a check is one HTTP call with one outcome, and only
      # the latest one tells you anything.
      t.datetime :last_checked_at
      t.string :last_check_status
      t.string :last_check_error

      t.timestamps
    end

    add_index :inference_servers, :type
    # Servers are picked by name in the UI, and two "Ollama"s would be
    # indistinguishable in a model list that shows the name and nothing else.
    add_index :inference_servers, :name, unique: true
  end
end
