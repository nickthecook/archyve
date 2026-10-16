# The preferred flag became Setting["chat.default_model_id"]: one model is ever
# the default, and saying so with a column meant a partial unique index, a
# callback and a validation all guarding the same singleton.
class MoveDefaultChatModelToSettings < ActiveRecord::Migration[8.0]
  def up
    carry_the_incumbent_over
    remove_column :inference_models, :preferred
  end

  def down
    add_column :inference_models, :preferred, :boolean, default: false, null: false
    add_index :inference_models, :preferred,
      name: "index_inference_models_on_preferred_chat",
      unique: true,
      where: "(preferred AND (kind = 0))"
    carry_the_incumbent_back
  end

  private

  def carry_the_incumbent_over
    id = select_value("SELECT id FROM inference_models WHERE preferred AND kind = 0 LIMIT 1")
    return if id.nil?

    execute(sanitize(<<~SQL, id.to_s))
      INSERT INTO settings (key, value, created_at, updated_at)
      VALUES ('chat.default_model_id', ?, NOW(), NOW())
      ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
    SQL
  end

  def carry_the_incumbent_back
    id = select_value("SELECT value FROM settings WHERE key = 'chat.default_model_id'")
    return if id.blank?

    execute(sanitize("UPDATE inference_models SET preferred = TRUE WHERE id = ? AND kind = 0", id.to_i))
    execute("DELETE FROM settings WHERE key = 'chat.default_model_id'")
  end

  def sanitize(sql, *values)
    ActiveRecord::Base.sanitize_sql_array([sql, *values])
  end
end
