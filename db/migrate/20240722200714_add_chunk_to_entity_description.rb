class AddChunkToEntityDescription < ActiveRecord::Migration[7.1]
  def change
    add_reference :entity_descriptions, :chunk, null: false, foreign_key: true
  end
end
