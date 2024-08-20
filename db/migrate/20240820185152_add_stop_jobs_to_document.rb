class AddStopJobsToDocument < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :stop_jobs, :boolean, default: false
  end
end
