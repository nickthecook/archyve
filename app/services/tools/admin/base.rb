# frozen_string_literal: true

module Tools
  module Admin
    # Read-only views of Archyve's own state, for the Admin Support agent.
    # Each tool reads a fixed set of columns; none of them reach conversations,
    # request bodies, credentials or keys. See issue #92.
    class Base < RubyLLM::Tool
      MAX_ROUNDS = 4
      MAX_LIMIT = 25

      def initialize(observer: nil)
        @observer = observer
        @rounds = 0
        super()
      end

      # The noun phrase the transcript panel names: "Checked <label>".
      def label = raise(NotImplementedError, "#{self.class} must say what it checks")

      def call(**)
        return Reply.call(budget_spent) if @rounds >= MAX_ROUNDS

        @rounds += 1
        @observer&.tool_started(name, label)
        Reply.call(super).tap { @observer&.tool_finished(it) }
      end

      private

      def capped(limit, default:) = (limit || default).to_i.clamp(1, MAX_LIMIT)

      def budget_spent
        {
          status: "budget_spent",
          instruction: "You have already checked #{label} #{MAX_ROUNDS} times this turn. " \
                       "Answer from what you already have."
        }
      end
    end
  end
end
