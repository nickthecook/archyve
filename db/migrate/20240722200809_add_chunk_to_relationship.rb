class AddChunkToRelationship < ActiveRecord::Migration[7.1]
  def change
    add_reference :relationships, :chunk, null: false, foreign_key: true
  end
end
