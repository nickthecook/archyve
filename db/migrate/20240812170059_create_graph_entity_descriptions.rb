class CreateGraphEntityDescriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :graph_entity_descriptions do |t|
      t.references :graph_entity, null: false, foreign_key: true
      t.string :description
      t.references :chunk, null: false, foreign_key: true

      t.timestamps
    end
  end
end
