class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.belongs_to :collection, null: false, foreign_key: true
      t.belongs_to :user, null: false, foreign_key: true
      t.string :filename

      t.timestamps
    end
  end
end
