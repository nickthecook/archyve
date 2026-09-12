# frozen_string_literal: true

module Retrieval
  # Why a retrieval couldn't run. Carries the facts, not the sentence: the
  # search page words this one way, the chat tool words it another, and an
  # admin is told how to fix what a reader only needs to know about.
  #
  # `:not_configured` and `:unreachable` are genuinely different failures —
  # there is nothing to reach yet, versus something that should have answered
  # and didn't — and they get different messages everywhere they surface.
  Failure = Data.define(:kind, :server_name, :model_name) do
    def initialize(kind:, server_name: nil, model_name: nil)
      super
    end

    def not_configured? = kind == :not_configured
  end
end
