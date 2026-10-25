# What the deployment calls itself. Archyve's own brand is the default, and the
# only one until branding settings exist (issue #85).
class Brand < Data.define(:name, :ask_placeholder, :chat_placeholder)
  ARCHYVE = new(
    name: "ARCHYVE",
    ask_placeholder: "Consult the archive",
    chat_placeholder: "What do you want to know?"
  )

  def self.current = ARCHYVE
end
