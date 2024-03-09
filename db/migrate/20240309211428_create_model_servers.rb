class CreateModelServers < ActiveRecord::Migration[7.1]
  def change
    create_table :model_servers do |t|
      t.string :name
      t.string :url
      t.integer :provider
      t.boolean :default

      t.timestamps
    end
  end
end
