class AddEmbeddingContentToChunk < ActiveRecord::Migration[7.1]
  def change
    add_column :chunks, :embedding_content, :string, default: nil, null: true
  end
end
