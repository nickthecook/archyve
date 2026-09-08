module Sources
  # The default source: documents come from user uploads rather than an external
  # source. Kept as a source so all ingestion shares one pipeline, and one per
  # person so uploads have an owner.
  class ManualUpload < Source
    # Uploads are filed one at a time, by whoever uploads them, choosing the
    # collection as they go. A standing feed would mean every file that person
    # ever uploads silently joins that collection — which is not what "upload
    # this to the handbook" asked for.
    def self.feeds_collections? = false
  end
end
