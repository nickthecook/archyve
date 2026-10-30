class HelpController < ApplicationController
  def show
    if (image = HelpPage.image(params[:path]))
      send_file image, disposition: :inline
    elsif (page = HelpPage.find(params[:path]))
      render Views::Help::Show.new(page:, contents: HelpPage.sidebar)
    else
      raise ActionController::RoutingError, "No help page at #{params[:path]}"
    end
  end
end
