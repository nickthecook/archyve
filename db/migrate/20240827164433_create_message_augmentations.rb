class CreateMessageAugmentations < ActiveRecord::Migration[7.1]
  def change
    create_table :message_augmentations do |t|
      t.references :message, null: false, foreign_key: true
      t.references :augmentation, null: false, polymorphic: true

      t.timestamps
    end
  end
end
