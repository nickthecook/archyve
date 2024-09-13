module ApplicationHelper
  include Pagy::Frontend

  def user_dom_id(id)
    "#{current_user.id}_#{id}"
  end

  def random_bg_image
    return "" if Rails.configuration.dark_backgrounds.empty?

    num_bgs = Rails.configuration.dark_backgrounds.length
    Rails.configuration.dark_backgrounds[rand(0..num_bgs - 1)]
  end
end
