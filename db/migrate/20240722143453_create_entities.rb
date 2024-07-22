class CreateEntities < ActiveRecord::Migration[7.1]
  def change
    create_table :entities do |t|
      t.string :name
      t.string :entity_type

      t.timestamps
    end
  end
end
