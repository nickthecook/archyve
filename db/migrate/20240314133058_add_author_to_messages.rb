class AddAuthorToMessages < ActiveRecord::Migration[7.1]
  def change
    add_reference :messages, :author, polymorphic: true, null: true

    Message.all.each do |message|
      message.update!(author: message.user)
    end

    change_column_null :messages, :author_id, false
  end
end
