class CreateSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :settings do |t|
      t.string :key
      t.jsonb :value

      t.timestamps
    end
  end
end
