class CreateGraphRelationships < ActiveRecord::Migration[7.1]
  def change
    create_table :graph_relationships do |t|
      t.references :from_entity, null: false, foreign_key: { to_table: :graph_entities }
      t.references :to_entity, null: false, foreign_key: { to_table: :graph_entities }
      t.references :chunk, null: false, foreign_key: true
      t.integer :strength
      t.string :description, null: false

      t.timestamps
    end
  end
end
