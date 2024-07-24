class AddProgressToDocument < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :current_step, :integer
    add_column :documents, :step_count, :integer
  end
end
