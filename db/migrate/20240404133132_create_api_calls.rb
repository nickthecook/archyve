class CreateApiCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :api_calls do |t|
      t.string :service_name, null: false
      t.string :category, null: false
      t.integer :http_method, null: false
      t.string :url, null: false
      t.jsonb :request_body
      t.integer :response_code
      t.jsonb :response_body
      t.integer :request_size, null: false
      t.integer :response_size, null: false

      t.timestamps
    end
  end
end
