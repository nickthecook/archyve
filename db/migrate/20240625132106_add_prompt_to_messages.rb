class AddPromptToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :prompt, :string
  end
end
