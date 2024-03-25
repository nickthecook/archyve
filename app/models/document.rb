class Document < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  has_one_attached :file
  has_many :chunks, dependent: :destroy

  include Turbo::Broadcastable
  include AASM

  after_create_commit -> { 
    broadcast_append_to(
      :collection,
      target: "documents",
      partial: "shared/document"
    )
  }
  after_update_commit -> { 
    broadcast_replace_to(
      :collections,
      target: "document_#{id}",
      partial: "shared/document",
      document: @document
    )
    broadcast_replace_to(
      :documents,
      target: "docuemnt_#{id}-details",
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
    chunked: 1,
    embedded: 2,
    stored: 3,
    errored: 10
  }
  
  aasm column: :state do
    state :created
    state :chunked
    state :embedded
    state :stored
    state :error

    event :reset do
      # TODO: validate that there are no chunks in the db
      transitions from: [:chunked, :embedded, :stored], to: :created
    end

    event :chunk do
      transitions from: :created, to: :chunked
    end

    event :embed do
      transitions from: :chunked, to: :embedded
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
