class AddTypeAndParentToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_reference :documents, :parent, null: true, foreign_key: { to_table: "documents" }
  end
end
