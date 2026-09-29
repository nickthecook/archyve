class CreateSourceReprocesses < ActiveRecord::Migration[8.1]
  def change
    create_table :source_reprocesses do |t|
      t.references :source, null: false, foreign_key: true
      t.string :status, null: false, default: "running"
      t.bigint :cursor, null: false, default: 0
      t.integer :total, null: false, default: 0
      t.integer :enqueued, null: false, default: 0
      t.datetime :finished_at

      t.timestamps
    end

    # One run at a time per source, enforced where it matters rather than left
    # to the controller: the button is clickable twice before the first request
    # has finished.
    add_index :source_reprocesses, :source_id, unique: true, where: "status = 'running'",
      name: "index_source_reprocesses_on_running_source"
  end
end
