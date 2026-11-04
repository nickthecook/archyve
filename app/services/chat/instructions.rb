# frozen_string_literal: true

module Chat
  # The system prompt: the agent's voice, then the rules its toolsets depend on,
  # then the instance purpose. See "The system prompt" in docs/architecture.md.
  class Instructions
    def self.for(conversation) = new(conversation).to_s

    def initialize(conversation)
      @conversation = conversation
    end

    def to_s
      [@conversation.agent.prompt, *@conversation.toolsets.map(&:instructions), purpose_addendum]
        .compact_blank.join("\n\n")
    end

    private

    # Last, so an admin's purpose can never override the rules above it.
    def purpose_addendum
      purpose = Setting.chat_instance_purpose
      return if purpose.blank?

      "This instance's purpose, set by its administrator: #{purpose}"
    end
  end
end
