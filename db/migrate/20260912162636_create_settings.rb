class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :key, null: false, index: { unique: true }
      # Stored as text whatever the setting's type is; Setting::DEFINITIONS
      # decides how to read it back. A row exists only once someone changes the
      # setting — the default lives in code, not in a seed.
      t.string :value

      t.timestamps
    end
  end
end
