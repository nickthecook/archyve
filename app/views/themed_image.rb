# frozen_string_literal: true

# The theme can follow the device, which the server never sees, so with both
# images set both are sent and CSS shows one. Either stands in for the other.
class Views::ThemedImage < Components::Base
  def initialize(default:, light:, **attributes)
    @default = default
    @light = light
    @attributes = attributes
  end

  def view_template
    if @default && @light
      image(@default, "light:hidden")
      image(@light, "hidden light:inline")
    else
      image(@default || @light)
    end
  end

  private

  def image(attachment, visibility = nil)
    img(**@attributes, src: rails_blob_path(attachment, only_path: true), class: [@attributes[:class], visibility])
  end
end
