module Ingestion
  # Extraction came back with nothing to chunk. A document in this state would
  # otherwise be marked `processed` while holding no passages at all — which in
  # a RAG archive is worse than a failure, because nothing ever retrieves it and
  # nothing says why. It matters most on a partial conversion, where docling
  # reports a shortfall and the part that survived turns out to be empty.
  class NothingReadable < StandardError; end
end
