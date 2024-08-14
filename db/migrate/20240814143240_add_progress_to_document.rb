class AddProgressToDocument < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :process_step, :integer
    add_column :documents, :process_steps, :integer
  end
end
