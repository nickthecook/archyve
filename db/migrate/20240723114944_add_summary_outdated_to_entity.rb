class AddSummaryOutdatedToEntity < ActiveRecord::Migration[7.1]
  def change
    add_column :entities, :summary_outdated, :boolean, default: false
  end
end
