class CreateConversationCollections < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_collections do |t|
      t.belongs_to :conversation, null: false, foreign_key: true
      t.belongs_to :collection, null: false, foreign_key: true

      t.timestamps
    end
  end
end
