class Collection < ApplicationRecord
  has_many :documents, dependent: :destroy
  has_many :conversation_collections, dependent: :destroy
  belongs_to :embedding_model, class_name: "ModelConfig"
  belongs_to :entity_extraction_model, class_name: "ModelConfig", optional: true
  has_many :graph_entities, dependent: :destroy
  has_many :graph_relationships_from, through: :graph_entities
  has_many :graph_relationships_to, through: :graph_entities

  validates :name, presence: true

  after_create_commit lambda {
    broadcast_append_to(
      :collections,
      target: "collection_list_items",
      partial: "shared/collection_list_item",
      locals: {
        collection: self,
        selected: false,
      }
    )
  }
  after_update_commit lambda {
    broadcast_replace_to(
      :collections,
      target: "collection_#{id}_list_item",
      partial: "shared/collection_list_item",
      locals: {
        collection: self,
        selected: false,
      }
    )
    broadcast_replace_to(
      :collections,
      target: "collection_#{id}_state_tags",
      partial: "collections/state_tags",
      locals: {
        collection: self,
        selected: false,
      }
    )
  }
  after_destroy_commit lambda {
    broadcast_remove_to(
      :collections,
      target: "collection_#{id}_list_item"
    )
  }

  enum state: {
    created: 0,
    summarizing: 1,
    summarized: 2,
    vectorizing: 3,
    vectorized: 4,
    graphing: 5,
    graphed: 6,
    stopped: 7,
    deleting: 10,
    errored: 20,
  }

  def generate_slug
    update!(slug: "#{id}-#{name.parameterize}")
  end

  def summarized?
    graph_entities.where(summary: nil).none?
  end
end
