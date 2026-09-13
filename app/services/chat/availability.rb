# frozen_string_literal: true

module Chat
  # Whether chat can answer anything yet, and what to say when it can't.
  #
  # Two surfaces need this and have to agree: the chat page, which disables its
  # composer, and the landing, whose bar asks a question now and has to fall
  # back to searching when nothing can answer one. A fresh install has neither
  # model — nothing is seeded unless OLLAMA_API_BASE is set — so "not ready" is
  # an ordinary state rather than an error.
  #
  # An admin is told where to fix it; everyone else is told it isn't ready,
  # because only an admin can fix it and pointing a reader at a Settings page
  # they can't open is worse than telling them nothing.
  class Availability
    def self.reason_for(user) = new(user).reason

    def initialize(user)
      @user = user
    end

    def ready? = reason.nil?

    # nil when chat can run — which is why this memoises on `defined?` rather
    # than on the value. nil is the answer that matters most, and the other way
    # round it would re-run both lookups every time.
    def reason
      return @reason if defined?(@reason)

      @reason = unready_reason
    end

    private

    def unready_reason
      return if InferenceModel.default_chat && InferenceModel.active_embedding

      if @user.admin?
        "Chat needs a tool-capable chat model and an embedding model. Add them under Settings › Inference."
      else
        "Chat isn't available yet — an admin needs to configure a chat model."
      end
    end
  end
end
