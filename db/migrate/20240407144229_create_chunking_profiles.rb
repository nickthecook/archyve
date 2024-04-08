class CreateChunkingProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :chunking_profiles do |t|
      t.string :method
      t.integer :size
      t.integer :overlap

      t.timestamps
    end
  end
end
