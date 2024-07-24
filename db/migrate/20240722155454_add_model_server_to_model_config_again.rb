class AddModelServerToModelConfigAgain < ActiveRecord::Migration[7.1]
  def change
    add_reference :model_configs, :model_server, default: nil, null: true, foreign_key: true
  end
end
