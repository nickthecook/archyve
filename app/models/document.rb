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
      :conversations,
      target: "document_#{id}",
      partial: "documents/document"
    )
  }

  def contents
    file.download
  end
end
