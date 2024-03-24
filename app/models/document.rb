class Document < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  has_one_attached :file

  include Turbo::Broadcastable

  after_create_commit -> { 
    broadcast_append_to(
      :collection,
      target: "documents",
      partial: "documents/document"
    )
  }
  after_update_commit -> { 
    broadcast_replace_to(
      :collections,
      target: "document_#{id}",
      partial: "documents/document"
    )
  }
  after_destroy_commit -> {
    broadcast_remove_to(
      :collection,
      target: "document_#{id}"
    )
  }

  def contents
    file.download
  end
end
