class Add1536DimensionEmbeddings < ActiveRecord::Migration[8.1]
  def change
    rename_column :embeddings, :embedding, :embedding_768
    add_column :embeddings, :embedding_1536, :vector, limit: 1536
    add_index :embeddings, :embedding_1536, using: :hnsw, opclass: :vector_cosine_ops
  end
end
