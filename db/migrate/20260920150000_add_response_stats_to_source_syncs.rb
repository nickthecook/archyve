class AddResponseStatsToSourceSyncs < ActiveRecord::Migration[8.1]
  def up
    # A crawl's dispositions, rolled up once when the run reaches a terminal
    # status and its per-URL rows are reaped. Keys are mixed on purpose: numeric
    # strings for HTTP responses, named buckets for the failures that never got
    # one ("timeout", "connection_failed"). See docs/todo.md, "The web source".
    add_column :source_syncs, :response_stats, :jsonb, default: {}, null: false
  end

  def down
    remove_column :source_syncs, :response_stats
  end
end
