class AddEntitiesExtractedToChunk < ActiveRecord::Migration[7.1]
  def change
    add_column :chunks, :entities_extracted, :boolean, default: false
  end
end
