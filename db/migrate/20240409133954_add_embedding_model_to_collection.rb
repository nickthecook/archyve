class AddEmbeddingModelToCollection < ActiveRecord::Migration[7.1]
  def change
    add_reference :collections, :embedding_model, null: true, foreign_key: { to_table: :model_configs }

    embedding_model = ModelConfig.create!(name: "all-minilm", model_server: ModelServer.first) do |mc|
      mc.model = "all-minilm",
      mc.embedding = true,
      mc.model_server = ModelServer.first
    end

    Collection.all.each { |c| c.update!(embedding_model: embedding_model) }

    change_column_null :collections, :embedding_model_id, false
  end
end
