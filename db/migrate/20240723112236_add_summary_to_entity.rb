class AddSummaryToEntity < ActiveRecord::Migration[7.1]
  def change
    add_column :entities, :summary, :string
  end
end
