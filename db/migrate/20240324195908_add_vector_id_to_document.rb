class AddVectorIdToDocument < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :vector_id, :string
  end
end
