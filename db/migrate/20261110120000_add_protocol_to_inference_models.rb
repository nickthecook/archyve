class AddProtocolToInferenceModels < ActiveRecord::Migration[8.1]
  def up
    add_column :inference_models, :protocol, :string

    execute <<~SQL
      UPDATE inference_models
      SET protocol = CASE
        WHEN kind = 0 AND name ~ 'gpt-5\\.[4-9]|gpt-5[0-9]|gpt-[6-9]' THEN 'responses'
        ELSE 'chat_completions'
      END
    SQL

    change_column_null :inference_models, :protocol, false
  end

  def down
    remove_column :inference_models, :protocol
  end
end
