module Sources
  # The default source: documents come from user uploads rather than an
  # external source. Kept as a source so all ingestion shares one pipeline.
  class ManualUpload < Source
  end
end
