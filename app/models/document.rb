class Document < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  has_one_attached :file

  include Turbo::Broadcastable
  include AASM

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

  enum state: {
    created: 0,
    embedded: 1,
    stored: 2,
    errored: 3
  }
  
  aasm column: :state do
    state :created
    state :embedded
    state :stored
    state :error

    event :embed do
      transitions from: :created, to: :embedded
    end

    event :store do
      transitions from: [:created, :embedded], to: :stored
    end

    event :error do
      transitions from: [:embedded, :stored], to: :errored
    end
  end

  def contents
    file.download
  end
end
