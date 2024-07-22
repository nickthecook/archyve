class CreateEntityDescriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :entity_descriptions do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :description

      t.timestamps
    end
  end
end
