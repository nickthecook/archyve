class ChangeAuthorIdToNullableInMessages < ActiveRecord::Migration[7.1]
  def change
    change_column_null :messages, :author_id, true
  end
end
