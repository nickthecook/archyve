class AddStiTypeToDocuments < ActiveRecord::Migration[7.1]
  def up
    add_column :documents, :type, :string
    add_index :documents, :type

    Document.where("filename LIKE 'fact-%'").update_all(type: "Fact")
  end

  def down
    remove_column :documents, :type
  end
end
