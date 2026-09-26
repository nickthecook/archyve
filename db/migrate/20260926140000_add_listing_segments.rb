class AddListingSegments < ActiveRecord::Migration[8.1]
  def change
    # What a listing segment listed: collections, or a page of one collection's
    # documents. Nothing here is a passage, so a listing has no hits — the rows
    # it showed live in the segment itself or nowhere.
    add_column :segments, :listing, :jsonb
  end
end
