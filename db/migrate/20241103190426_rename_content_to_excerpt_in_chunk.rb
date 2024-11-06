class RenameContentToExcerptInChunk < ActiveRecord::Migration[7.1]
  def up
    rename_column :chunks, :content, :excerpt
  end

  def down
    rename_column :chunks, :excerpt, :content
  end
end
