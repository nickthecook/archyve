class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients do |t|
      t.string :name
      t.belongs_to :user, null: false, foreign_key: true
      t.string :api_key

      t.timestamps
    end
  end
end
