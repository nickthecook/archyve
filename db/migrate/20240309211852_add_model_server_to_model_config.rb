class AddModelServerToModelConfig < ActiveRecord::Migration[7.1]
  def change
    add_reference :model_configs, :model_server, null: false, foreign_key: true
  end
end
