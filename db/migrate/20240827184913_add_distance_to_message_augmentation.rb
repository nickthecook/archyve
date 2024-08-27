class AddDistanceToMessageAugmentation < ActiveRecord::Migration[7.1]
  def change
    add_column :message_augmentations, :distance, :float
  end
end
