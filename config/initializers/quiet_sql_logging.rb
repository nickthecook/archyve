# frozen_string_literal: true

# Some tables are pure infrastructure: the log line costs more than it tells us.
#
# - Embedding rows carry a 768-dimension vector, so logging their SQL dumps the
#   whole vector (a wall of floats) on every load and store.
# - SolidCable messages carry a hex-encoded Turbo Stream payload, and inference
#   writes one per token-flush — thousands of blobs per chat response. Solid
#   Cable silences its own *polling* reads (`silence_polling`), but not the
#   inserts the broadcast side makes.
#
# Everything else keeps logging normally. Only affects environments that log SQL
# at all (dev/test at :debug); production doesn't, so this is a no-op there.
module QuietSqlLogging
  # Matched against the query name ActiveRecord assigns, e.g. "Embedding Load",
  # "SolidCable::Message Insert".
  NOISY_PREFIXES = %w[Embedding SolidCable SolidQueue].freeze

  def sql(event)
    name = event.payload[:name]
    return if name.is_a?(String) && name.start_with?(*NOISY_PREFIXES)

    super
  end
end

ActiveRecord::LogSubscriber.prepend(QuietSqlLogging)

# Prepending puts a frame from this file on the stack above the code that
# actually ran the query, and `verbose_query_logs` reports the first *unsilenced*
# frame — so without this every query's "↳" would point here instead of at its
# real caller.
#
# Registering inside on_load(:active_record) is load-bearing: the ActiveRecord
# railtie assigns `LogSubscriber.backtrace_cleaner = Rails.backtrace_cleaner`
# from its own hook, so a silencer added beforehand is attached to an object that
# then gets thrown away. The surviving cleaner strips the Rails.root prefix
# before silencers see a line, hence matching the basename, not __FILE__.
ActiveSupport.on_load(:active_record) do
  ActiveRecord::LogSubscriber.backtrace_cleaner.add_silencer do |line|
    line.include?("quiet_sql_logging.rb")
  end
end
