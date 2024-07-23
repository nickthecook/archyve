class AddCollectionToEntity < ActiveRecord::Migration[7.1]
  def change
    add_reference :entities, :collection, null: false, foreign_key: true
  end
end
