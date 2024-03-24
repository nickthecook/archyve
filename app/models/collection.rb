class Collection < ApplicationRecord
  has_many :documents

  def generate_slug
    update!(slug: "#{id}-#{name.parameterize}")
  end
end
