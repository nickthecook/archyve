class AddVectorIdToGraphEntity < ActiveRecord::Migration[7.1]
  def change
    add_column :graph_entities, :vector_id, :string
  end
end
