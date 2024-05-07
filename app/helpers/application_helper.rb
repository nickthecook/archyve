module ApplicationHelper
  include Pagy::Frontend

  def user_dom_id(id)
    "#{current_user.id}_#{id}"
  end
end
