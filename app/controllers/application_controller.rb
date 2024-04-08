class ApplicationController < ActionController::Base
  include Pagy::Backend

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :set_current_user

  private

  def render_not_found
    render file: Rails.root.join("public/404.html"), status: :not_found
  end

  def set_current_user
    @current_user = current_user
  end
end
