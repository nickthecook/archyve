class CreateChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :chunks do |t|
      t.belongs_to :document, null: false, foreign_key: true
      t.string :vector_id
      t.string :content
      t.jsonb :embeddings

      t.timestamps
    end
  end
end
