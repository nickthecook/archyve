class CreateEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :embeddings do |t|
      t.references :chunk, null: false, foreign_key: true
      t.string :embedding_model, null: false        # e.g. "nomic-embed-text"
      t.vector :embedding, limit: 768               # pgvector column; nomic-embed-text = 768 dims

      t.timestamps
    end

    # One embedding per chunk per model (supports future multi-model coexistence).
    add_index :embeddings, [:chunk_id, :embedding_model], unique: true
    # Approximate nearest-neighbor index. Cosine ops for (normalized) text embeddings.
    add_index :embeddings, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
