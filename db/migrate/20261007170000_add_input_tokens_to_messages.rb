class AddInputTokensToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :input_tokens, :integer
  end
end
