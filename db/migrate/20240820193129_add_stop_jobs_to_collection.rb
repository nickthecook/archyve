class AddStopJobsToCollection < ActiveRecord::Migration[7.1]
  def change
    add_column :collections, :stop_jobs, :boolean, default: false
  end
end
