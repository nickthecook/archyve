class AddRawContentToMessage < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :raw_content, :string
  end
end
