class AddEntityExtractionModelToCollection < ActiveRecord::Migration[7.1]
  def change
    add_reference :collections, :entity_extraction_model, null: true, foreign_key: { to_table: :model_configs }
  end
end
