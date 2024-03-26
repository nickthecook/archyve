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
      :collection,
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
    chunking: 4,
    chunked: 1,
    embedding: 5,
    embedded: 2,
    storing: 6,
    stored: 3,
    errored: 10
  }

  aasm column: :state do
    state :created
    state :chunking
    state :chunked
    state :embedding
    state :embedded
    state :storing
    state :stored
    state :error

    event :reset do
      # TODO: validate that there are no chunks in the db
      transitions from: [:chunking, :chunked, :embedding, :embedded, :storing, :stored], to: :created
    end

    event :chunking do
      transitions from: :created, to: :chunking
    end
    event :chunk do
      transitions from: :chunking, to: :chunked
    end
    event :embedding do
      transitions from: :chunked, to: :embedding
    end
    event :embed do
      transitions from: :embedding, to: :embedded
    end
    event :storing do
      transitions from: :embedded, to: :storing
    end
    event :store do
      transitions from: :storing, to: :stored
    end

    event :error do
      transitions from: [:embedded, :stored], to: :errored
    end
  end

  def contents
    file.download
  end

  def state_indexable?
    !state.end_with?("ing")
  end
end
