class AddLinkToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :link, :string
  end
end
