class AddStatusCodeToSourceSyncItems < ActiveRecord::Migration[8.1]
  def change
    # Nullable because half of what a crawl hits never reaches HTTP: a DNS
    # failure, a timeout, a URL robots.txt refuses. Those carry a named
    # disposition and no code.
    add_column :source_sync_items, :status_code, :integer
  end
end
