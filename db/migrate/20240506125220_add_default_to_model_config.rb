class AddDefaultToModelConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :model_configs, :default, :boolean, default: false

    # use most recent models as defaults
    ModelConfig.where(embedding: true).last&.update!(default: true)
    ModelConfig.where(embedding: false).last&.update!(default: true)
  end
end
