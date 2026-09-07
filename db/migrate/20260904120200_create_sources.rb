class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources do |t|
      t.string :type, null: false          # STI: Sources::ManualUpload, ...
      t.string :name, null: false
      t.jsonb :config, null: false, default: {}   # per-type settings (encrypt later)
      t.jsonb :state, null: false, default: {}     # sync cursor / bookkeeping
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :sources, :type
  end
end
