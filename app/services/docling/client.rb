module Docling
  # Thin client over docling-serve. Posts a document's bytes to the synchronous
  # convert endpoint and returns a Docling::Result (markdown + structured JSON).
  #
  # Sync is fine for now: uploads run inside the ProcessDocumentJob, so the job's
  # thread blocks on Docling, not a web request. If large PDFs make this too slow
  # we move to the async endpoints (/v1/convert/file/async + /v1/status/poll).
  class Client
    class Error < StandardError; end

    # Nothing answered, or something in front of docling answered for it: it's
    # down, misaddressed, or too slow. Whoever reads this goes and looks at the
    # deployment — the document is fine and will process on a retry.
    class Unreachable < Error; end

    # Docling answered, and said no. This one *is* about the document: the file
    # is corrupt, empty, encrypted, or a format it won't open. Retrying changes
    # nothing; replacing the file might.
    class ConversionFailed < Error; end

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
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise Unreachable, "docling did not respond: #{e.class}: #{e.message}"
    rescue Faraday::Error => e
      raise error_for(e)
    end

    private

    # A Faraday error carrying a response means docling answered, and the status
    # says whose problem it is: 5xx is docling (or a proxy) breaking, which
    # re-uploading will never fix; 4xx is docling refusing this particular file.
    #
    # The body comes along deliberately. It is the one place docling says *why*,
    # and flattening every failure here into one untyped sentence is what left
    # production unable to tell a dead service from a bad PDF.
    def error_for(error)
      status = error.response&.dig(:status)
      message = "docling returned #{status || 'an error'}: #{body_snippet(error)}"

      status.nil? || status >= 500 ? Unreachable.new(message) : ConversionFailed.new(message)
    end

    def body_snippet(error)
      body = error.response&.dig(:body)
      body.is_a?(String) ? body.strip.truncate(300) : error.message
    end

    # Docling's own verdict on a 200: it will report a per-file failure in the
    # envelope rather than with a status code, so a success here is two claims,
    # not one.
    def ensure_success!(result)
      return if result.status == "success" && result.errors.empty?

      raise ConversionFailed,
        "docling conversion failed (status=#{result.status.inspect}): #{result.errors.inspect}".truncate(300)
    end
  end
end
