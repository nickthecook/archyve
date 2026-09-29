class AddMarkdownToChunks < ActiveRecord::Migration[8.1]
  # Nullable, and stays that way: chunks written before this column existed
  # can't be backfilled — rebuilding the display form needs the Docling result,
  # which isn't kept — so they render from `content` until reprocessed.
  def change
    add_column :chunks, :markdown, :text
  end
end
