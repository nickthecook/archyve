module Docling
  # Thin client over docling-serve. Posts a document's bytes to the synchronous
  # convert endpoint and returns a Docling::Result (markdown + structured JSON).
  #
  # Sync is fine for now: uploads run inside the ProcessDocumentJob, so the job's
  # thread blocks on Docling, not a web request. If large PDFs make this too slow
  # we move to the async endpoints (/v1/convert/file/async + /v1/status/poll).
  class Client
    class Error < StandardError; end

    CONVERT_PATH = "/v1/convert/file".freeze
    # We only need the structured DoclingDocument that the chunker walks. Asking
    # for a second format (e.g. md for display) means a repeated `to_formats`
    # form field, which Faraday's multipart array encoding gets wrong — defer
    # that to the UI task (likely via the async JSON-body endpoint).
    TO_FORMAT = "json".freeze

    def initialize(base_url: ENV.fetch("DOCLING_URL", "http://localhost:5001"), timeout: 300)
      @conn = Http.connection(base_url, timeout: timeout)
    end

    # `io` is anything Faraday::Multipart::FilePart accepts (File, StringIO, path).
    def convert(io, filename:, content_type: "application/octet-stream")
      payload = {
        "files" => Faraday::Multipart::FilePart.new(io, content_type, filename),
        "to_formats" => TO_FORMAT
      }

      response = @conn.post(CONVERT_PATH, payload)
      result = Result.new(JSON.parse(response.body))
      ensure_success!(result)
      result
    rescue Faraday::Error => e
      raise Error, "docling request failed: #{e.class}: #{e.message}"
    end

    private

    def ensure_success!(result)
      return if result.status == "success" && result.errors.empty?

      raise Error, "docling conversion failed (status=#{result.status.inspect}): #{result.errors.inspect}"
    end
  end
end
