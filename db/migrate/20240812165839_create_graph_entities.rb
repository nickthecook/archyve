class CreateGraphEntities < ActiveRecord::Migration[7.1]
  def change
    create_table :graph_entities do |t|
      t.string :name
      t.string :entity_type
      t.references :collection, null: false, foreign_key: true
      t.string :summary
      t.boolean :summary_outdated

      t.timestamps
    end
  end
end
