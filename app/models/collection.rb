class Collection < ApplicationRecord
  has_many :documents

  def generate_slug
    update!(slug: name.parameterize)
  end
end
