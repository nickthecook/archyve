# Zeitwerk would read openai.rb as `Openai`. Teaching the autoloader the casing
# is better than spelling the class `Openai` everywhere it appears, not least
# because the STI `type` column stores the class name verbatim and admins see it
# in the URL when adding a server.
#
# Scoped to the autoloader rather than registered as an ActiveSupport acronym:
# an acronym changes camelize/underscore for the whole app, and nothing else
# here wants that.
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect("openai" => "OpenAI")
end
