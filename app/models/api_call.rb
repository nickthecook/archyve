class ApiCall < ApplicationRecord
  belongs_to :traceable

  enum http_method: { get: 0, post: 1, put: 2, delete: 3, patch: 4, head: 5 }
end
