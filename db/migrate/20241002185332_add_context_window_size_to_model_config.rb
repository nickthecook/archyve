class AddContextWindowSizeToModelConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :context_window_size, :integer
  end
end
