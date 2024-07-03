class CreateApiCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :api_calls do |t|
      t.string :service_name
      t.integer :http_method
      t.string :url
      t.jsonb :headers
      t.jsonb :body
      t.integer :body_length
      t.integer :response_code
      t.jsonb :response_headers
      t.jsonb :response_body
      t.integer :response_length
      t.references :traceable, polymorphic: true

      t.timestamps
    end
  end
end
