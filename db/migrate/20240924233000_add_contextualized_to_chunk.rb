class AddContextualizedToChunk < ActiveRecord::Migration[7.1]
  def change
    add_column :chunks, :contextualized, :boolean, default: false
  end
end
