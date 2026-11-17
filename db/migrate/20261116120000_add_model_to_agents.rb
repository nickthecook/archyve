class AddModelToAgents < ActiveRecord::Migration[8.1]
  def change
    add_reference :agents, :inference_model, foreign_key: { on_delete: :nullify }
    add_column :agents, :model_overridable, :boolean, default: true, null: false
  end
end
