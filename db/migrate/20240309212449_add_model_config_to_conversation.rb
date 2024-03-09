class AddModelConfigToConversation < ActiveRecord::Migration[7.1]
  def change
    add_reference :conversations, :model_config, null: false, foreign_key: true
  end
end
