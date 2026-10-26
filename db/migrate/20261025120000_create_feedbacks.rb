class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.references :message, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.integer :rating
      t.text :comment
      t.timestamps
    end
  end
end
