# What the deployment calls itself, read once per request. The defaults are
# Archyve's own, declared with the brand.* settings.
class Brand < Data.define(:name, :logo, :ask_placeholder, :chat_placeholder)
  def self.current
    Current.brand ||= new(
      name: Setting.brand_name,
      logo: Setting.brand_logo,
      ask_placeholder: Setting.brand_ask_placeholder,
      chat_placeholder: Setting.brand_chat_placeholder
    )
  end
end
