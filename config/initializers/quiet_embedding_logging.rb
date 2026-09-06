# frozen_string_literal: true

# An Embedding row carries a 768-dimension vector, so logging its SQL dumps the
# whole vector (a wall of floats) on every load and store — drowning out every
# other query in the log. Skip SQL logging for just this model; all other models
# keep logging normally.
#
# Only affects environments that log SQL at all (dev/test at :debug); production
# doesn't log SQL, so this is a no-op there.
module QuietEmbeddingLogging
  def sql(event)
    name = event.payload[:name]
    return if name.is_a?(String) && name.start_with?("Embedding")

    super
  end
end

ActiveRecord::LogSubscriber.prepend(QuietEmbeddingLogging)
