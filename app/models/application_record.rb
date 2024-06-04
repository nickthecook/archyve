class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def user_dom_id(suffix)
    "#{user.id}_#{suffix}"
  end
end
