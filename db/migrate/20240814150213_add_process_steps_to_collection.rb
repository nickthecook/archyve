class AddProcessStepsToCollection < ActiveRecord::Migration[7.1]
  def change
    add_column :collections, :process_step, :integer
    add_column :collections, :process_steps, :integer
  end
end
