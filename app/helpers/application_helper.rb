module ApplicationHelper
  include Pagy::Frontend

  def user_dom_id(id)
    "#{current_user.id}_#{id}"
  end

  def model_user_dom_id(model, suffix: "", user: nil)
    "#{user&.id || current_user.id}-#{model.class.name.underscore}-#{suffix}"
  end

  def random_bg_image
    return "" if Rails.configuration.dark_backgrounds.empty?

    num_bgs = Rails.configuration.dark_backgrounds.length
    Rails.configuration.dark_backgrounds[rand(0..num_bgs - 1)]
  end

  def entity_extraction_model_list
    ModelConfig.available.generation.where(
      "context_window_size >= ?",
      min_context_window_size
    ).order(context_window_size: :desc)
  end

  def min_context_window_size
    @min_context_window_size ||= Graph::CalculateMinContextSize.new.execute
  end
end
