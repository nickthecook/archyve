class Collection < ApplicationRecord
  has_many :documents, dependent: :destroy

  def generate_slug
    update!(slug: "#{id}-#{name.parameterize}")
  end
end
