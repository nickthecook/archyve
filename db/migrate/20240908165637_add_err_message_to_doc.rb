class AddErrMessageToDoc < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :error_message, :string
  end
end
