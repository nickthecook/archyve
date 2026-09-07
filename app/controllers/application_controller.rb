class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  # Views are Phlex components that carry their own Views::Layout shell, so skip
  # Rails' ERB layout lookup (otherwise pages get double-wrapped).
  layout false

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
