class AddEmbeddingModelToCollection < ActiveRecord::Migration[7.1]
  Collection

  class Collection < ApplicationRecord
    attribute :state, :string
  end

  def change
    add_reference :collections, :embedding_model, null: true, foreign_key: { to_table: :model_configs }

    Collection.where(embedding_model_id: nil).each { |c| c.update!(embedding_model_id: embedding_model.id) }

    change_column_null :collections, :embedding_model_id, false
  end
end
