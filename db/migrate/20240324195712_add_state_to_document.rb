class AddStateToDocument < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :state, :integer
  end
end
