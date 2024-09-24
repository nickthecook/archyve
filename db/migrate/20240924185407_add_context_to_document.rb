class AddContextToDocument < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :context, :jsonb
    add_column :documents, :context_model, :string
  end
end
