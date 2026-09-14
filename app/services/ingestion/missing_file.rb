module Ingestion
  # A document row with no bytes behind it. Its own error rather than a
  # NoMethodError on a nil blob, because it is a real state — an attachment
  # that failed to save, or a blob reaped out from under a document — and the
  # pipeline can name it instead of dying obscurely.
  class MissingFile < StandardError; end
end
