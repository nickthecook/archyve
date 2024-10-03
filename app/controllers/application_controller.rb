class ApplicationController < ActionController::Base
  include Pagy::Backend

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :set_current_user

  before_action :check_models

  def user_dom_id(id)
    "#{current_user.id}_#{id}"
  end

  def model_user_dom_id(model, suffix: "", user: nil)
    "#{user&.id || current_user.id}-#{model.class.name.underscore}-#{suffix}"
  end

  private

  def render_not_found
    render file: Rails.public_path.join('404.html'), status: :not_found
  end

  def set_current_user
    @current_user = current_user
  end

  def check_models
    @missing_models = CheckModelsService.new.execute
  end
end
