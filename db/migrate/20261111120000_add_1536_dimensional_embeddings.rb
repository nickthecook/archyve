class Add1536DimensionalEmbeddings < ActiveRecord::Migration[8.1]
  def change
    add_column :embeddings, :embedding_1536, :vector, limit: 1536
    add_index :embeddings, :embedding_1536, using: :hnsw, opclass: :vector_cosine_ops
  end
end
