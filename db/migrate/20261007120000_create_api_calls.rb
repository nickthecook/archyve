class CreateApiCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :api_calls do |t|
      t.string :service_name, null: false
      t.string :kind, null: false
      t.string :http_method, null: false
      t.string :url, null: false
      t.integer :response_code
      t.jsonb :request_headers
      t.jsonb :request_body
      t.integer :request_length
      t.jsonb :response_headers
      t.jsonb :response_body
      t.integer :response_length
      t.integer :duration_ms
      t.boolean :streamed, null: false, default: false
      t.string :error
      t.references :traceable, polymorphic: true
      t.timestamps
    end

    # The sweep deletes by age, and the only listing anyone wants is newest
    # first.
    add_index :api_calls, :created_at
  end
end
