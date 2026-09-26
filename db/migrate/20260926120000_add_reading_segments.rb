class AddReadingSegments < ActiveRecord::Migration[8.1]
  def change
    # A chunk the model read rather than found was never ranked against
    # anything, so it has neither. Nullable rather than zeroed: zero distance
    # means "identical to the query", and there was no query.
    change_column_null :hits, :distance, true
    change_column_null :hits, :score, true

    # Snapshotted for the same reason the snippet is: reingesting a document
    # destroys its chunks and renumbers the new ones, and a transcript that
    # read through to the live chunk would quietly rewrite itself.
    add_column :hits, :position, :integer

    # What a reading segment read: which document, which range, out of how
    # many. On the segment rather than derived from its hits, because the hits
    # outlive the chunks they came from.
    add_column :segments, :reading, :jsonb
  end
end
