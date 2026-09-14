# frozen_string_literal: true

module Ingestion
  # Why a document didn't make it through the pipeline. Mirrors
  # Retrieval::Failure on purpose, including the thing that matters most about
  # it: this carries the *facts*, not the sentence. A reader on a document page
  # is told what happened in words that mean something to them; an operator is
  # told which service to go and look at. Neither wording lives here.
  #
  # Two axes rather than one, because a single column can't answer both
  # questions. `stage` is where the pipeline gave up, `kind` is what went
  # wrong, and "Ollama was unreachable" and "Docling was unreachable" want
  # completely different next actions from whoever reads them.
  #
  # Subclassed from Data rather than written as `Data.define(…) do … end`: a
  # constant assigned inside that block is scoped to the *enclosing module*, so
  # the vocabularies below would silently become Ingestion::KINDS and nothing
  # referring to them by their proper name would resolve.
  class Failure < Data.define(:stage, :kind, :detail)
    # Where the pipeline gave up, in the order the job runs them. `nil` is
    # allowed and means the failure happened outside any of them — a database
    # write, say — which is worth being able to tell apart from extraction.
    STAGES = %w[extract chunk embed store].freeze

    # What went wrong, as a closed vocabulary the views can word. Split by what
    # the reader would have to *do*, not by which library raised: `unreachable`
    # is somebody fixing a deployment, `conversion_rejected` is somebody
    # replacing a file, `not_configured` is an administrator finishing a setup.
    #
    # Anything unrecognised lands on `internal`, which is the honest answer — an
    # unclassified failure is a bug report, not a diagnosis, and dressing it up
    # as one of the others would send its reader somewhere pointless.
    KINDS = %w[missing_file unreachable conversion_rejected not_configured dimension_mismatch internal].freeze

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

    # Ordered specific-to-general: every branch below `Faraday::Error` would
    # also match it, and the raise-time classes say more than the transport.
    def self.kind_for(error)
      case error
      when Ingestion::MissingFile then "missing_file"
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
  end
end
