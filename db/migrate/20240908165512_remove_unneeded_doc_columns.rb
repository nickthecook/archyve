class RemoveUnneededDocColumns < ActiveRecord::Migration[7.1]
  def change
    remove_column :documents, :process_steps
    remove_column :documents, :process_step
  end
end
