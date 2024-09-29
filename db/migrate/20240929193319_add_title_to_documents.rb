class AddTitleToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :title, :string
  end
end
