class AddEmbeddingToModelConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :embedding, :boolean, default: false
  end
end
