module Connectors
  # The default connector: documents come from user uploads rather than an
  # external source. Kept as a connector so all ingestion shares one pipeline.
  class ManualUpload < Connector
  end
end
