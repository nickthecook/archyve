class CreateModelConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :model_configs do |t|
      t.string :name
      t.string :model
      t.float :temperature
      t.string :system_prompt

      t.timestamps
    end
  end
end
