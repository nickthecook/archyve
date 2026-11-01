# frozen_string_literal: true

module Ingestion
  # The pipeline's verdict on one document, for whoever has to act on it.
  #
  # Like Retrieval::Outcome, it exists because the interesting states are more
  # than two. A document can fail; it can also come through *with a shortfall*
  # — docling converts a manual and reports that page 2 didn't parse — and
  # collapsing that into either "processed" or "failed" loses the only fact
  # worth having. Rejecting the whole manual over one page is worse: fifty-nine
  # readable pages retrieve better than none.
  #
  # And like Retrieval::Failure, it carries the *facts*, not the sentence. A
  # reader is told what happened to their document in words that mean something
  # to them; a curator is told which service to go and look at. Neither
  # wording lives here.
  #
  # Two axes rather than one, because a single column can't answer both
  # questions. `stage` is where the pipeline stopped or stumbled, `kind` is
  # what happened, and "Ollama was unreachable" and "Docling was unreachable"
  # want completely different next actions from whoever reads them.
  #
  # Subclassed from Data rather than written as `Data.define(…) do … end`: a
  # constant assigned inside that block is scoped to the *enclosing module*, so
  # the vocabularies below would silently become Ingestion::KINDS and nothing
  # referring to them by their proper name would resolve.
  class Outcome < Data.define(:stage, :kind, :detail)
    # Where the pipeline was, in the order the job runs them. `nil` is allowed
    # and means it happened outside all of them — a database write, say — which
    # is worth being able to tell apart from extraction.
    STAGES = %w[extract chunk embed store].freeze

    # Nothing usable came out; the document is `failed`. Split by what the
    # reader would have to *do*, not by which library raised: `unreachable` is
    # somebody fixing a deployment, `conversion_rejected` is somebody replacing
    # a file, `not_configured` is an administrator finishing a setup.
    #
    # Anything unrecognised lands on `internal`, which is the honest answer — an
    # unclassified failure is a bug report, not a diagnosis, and dressing it up
    # as one of the others would send its reader somewhere pointless.
    FAILURE_KINDS = %w[missing_file unreachable conversion_rejected not_configured dimension_mismatch internal].freeze

    # Something usable came out, but not all of it; the document is `processed`
    # and searchable, and says so with a caveat. This is the distinction the
    # rename bought — these could not be recorded at all while the columns were
    # called `failure_*`.
    SHORTFALL_KINDS = %w[partial_extraction].freeze

    KINDS = (FAILURE_KINDS + SHORTFALL_KINDS).freeze

    # Truncated because this is going in a column and onto a page, and a stack
    # trace pasted into either is unreadable in both. The first line of an
    # exception message is where the answer lives.
    DETAIL_LIMIT = 500

    def self.classify(error, stage: nil)
      new(
        stage: stage&.to_s.presence,
        kind: kind_for(error),
        detail: "#{error.class}: #{error.message}".truncate(DETAIL_LIMIT)
      )
    end

    # Docling converted the document and told us what it couldn't manage. Its
    # own error list is the detail: it names the page and the component, which
    # is exactly what someone deciding whether to re-scan the original needs.
    def self.partial_extraction(result)
      new(
        stage: "extract",
        kind: "partial_extraction",
        detail: "docling reported #{result.errors.inspect}".truncate(DETAIL_LIMIT)
      )
    end

    # Ordered specific-to-general: every branch below `Faraday::Error` would
    # also match it, and the raise-time classes say more than the transport.
    def self.kind_for(error)
      case error
      when Ingestion::MissingFile then "missing_file"
      when Ingestion::NothingReadable then "conversion_rejected"
      when Docling::Client::Unreachable then "unreachable"
      when Docling::Client::ConversionFailed then "conversion_rejected"
      when Embeddings::Embed::NotConfigured then "not_configured"
      when Embeddings::Embed::DimensionMismatch then "dimension_mismatch"
      when *ruby_llm_unreachable then "unreachable"
      when *ruby_llm_misconfigured then "not_configured"
      when Faraday::ConnectionFailed, Faraday::TimeoutError then "unreachable"
      else "internal"
      end
    end

    # An embedding server that answered with a 5xx, a refusal to serve, or "I'm
    # busy" is one nobody fixes by re-uploading — same conclusion as a refused
    # connection, so the same kind.
    def self.ruby_llm_unreachable
      [RubyLLM::ServerError, RubyLLM::ServiceUnavailableError, RubyLLM::OverloadedError, RubyLLM::RateLimitError]
    end

    # Rejected credentials and a model the server has never heard of are both
    # somebody's Settings › Inference entry being wrong, not an outage.
    def self.ruby_llm_misconfigured
      [RubyLLM::UnauthorizedError, RubyLLM::ForbiddenError, RubyLLM::PaymentRequiredError, RubyLLM::ModelNotFoundError]
    end

    def failure? = FAILURE_KINDS.include?(kind)
    def shortfall? = SHORTFALL_KINDS.include?(kind)
  end
end
