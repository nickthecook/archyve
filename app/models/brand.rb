# What the deployment calls itself, read once per request. The defaults are
# Archyve's own, declared with the brand.* settings.
class Brand < Data.define(
  :name, :title, :logo, :logo_light, :ask_placeholder, :chat_placeholder, :disclaimer, :corridor,
  :landing_image, :landing_image_light, :landing_image_fill, :landing_image_fade
)
  def self.current
    Current.brand ||= new(
      name: Setting.brand_name,
      title: Setting.brand_title,
      logo: Setting.brand_logo,
      logo_light: Setting.brand_logo_light,
      ask_placeholder: Setting.brand_ask_placeholder,
      chat_placeholder: Setting.brand_chat_placeholder,
      disclaimer: Setting.brand_disclaimer,
      corridor: Setting.brand_corridor?,
      landing_image: Setting.brand_landing_image,
      landing_image_light: Setting.brand_landing_image_light,
      landing_image_fill: Setting.brand_landing_image_fill?,
      landing_image_fade: Setting.brand_landing_image_fade?
    )
  end

  def corridor? = corridor

  def logo? = [logo, logo_light].any?

  def landing_image? = [landing_image, landing_image_light].any?

  def backdrop? = corridor? || landing_image?

  # The corridor wins whenever it's on, so filling only applies without it.
  def fill_screen? = !corridor? && landing_image? && landing_image_fill

  def tab_title = title.presence || name.presence
end
