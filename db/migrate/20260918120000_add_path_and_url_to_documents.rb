class AddPathAndUrlToDocuments < ActiveRecord::Migration[8.1]
  def change
    # Cross-source vocabulary, not a BookStack field: where this document sits
    # inside its source. Composes with Chunk#structure["heading_path"] into one
    # breadcrumb from the top of the source to the paragraph.
    add_column :documents, :path, :string

    # The document's address in the source, for sources that have one a reader's
    # browser can follow. See Source.user_accessible_links?.
    add_column :documents, :url, :string
  end
end
