class CreateAgents < ActiveRecord::Migration[8.1]
  def up
    create_table :agents do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :name, null: false
      t.text :prompt, null: false, default: ""
      t.boolean :built_in, null: false, default: false
      t.timestamps
    end

    # The prompt is left to db:seed, which owns built-in agents' text.
    archivist_id = select_value(<<~SQL)
      INSERT INTO agents (slug, name, built_in, created_at, updated_at)
      VALUES ('archivist', 'Archivist', true, now(), now())
      RETURNING id
    SQL

    add_reference :conversations, :agent, foreign_key: true
    execute "UPDATE conversations SET agent_id = #{archivist_id}"
    change_column_null :conversations, :agent_id, false
  end

  def down
    remove_reference :conversations, :agent
    drop_table :agents
  end
end
