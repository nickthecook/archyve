class AddMoreContextToChunk < ActiveRecord::Migration[7.1]
  def change
    add_column :chunks, :headings, :string
    add_column :chunks, :location_summary, :string
    add_column :chunks, :surrounding_content, :string
  end
end
