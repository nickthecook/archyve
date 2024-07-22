class CreateRelationships < ActiveRecord::Migration[7.1]
  def change
    create_table :relationships do |t|
      t.references :from, null: false, foreign_key: { to_table: :entities }
      t.references :to, null: false, foreign_key: { to_table: :entities }
      t.integer :strength
      t.string :description, null: false

      t.timestamps
    end
  end
end
