class Collection < ApplicationRecord
  has_many :documents, dependent: :destroy
  has_many :conversation_collections, dependent: :destroy
  belongs_to :embedding_model, class_name: "ModelConfig"

  def generate_slug
    update!(slug: "#{id}-#{name.parameterize}")
  end
end
