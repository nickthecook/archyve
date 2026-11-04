# frozen_string_literal: true

module Agents
  # Edit-time rules for sharing collections through an agent. A fixed set is
  # shared with everyone who can use the agent, so only someone who manages a
  # collection may put it in front of other people that way. See "Who can use
  # an agent" in docs/architecture.md.
  class Sharing
    def initialize(agent, by:)
      @agent = agent
      @by = by
    end

    # Takes the attributes about to be saved, before they are assigned.
    # nil when the change is allowed.
    def refusal(access_mode:, collection_mode:, collection_ids:)
      return unless shared?(access_mode, collection_mode)

      checked = Collection.where(id: collection_ids)
      checked = checked.where.not(id: @agent.collection_ids) if shared?(@agent.access_mode, @agent.collection_mode) && @agent.persisted?
      unmanaged = checked.order(:name).reject { @by.may_on?(it, :manager) }
      return if unmanaged.empty?

      "You can only share collections you manage, and you don't manage #{unmanaged.map(&:name).to_sentence}. " \
        "Keep the agent to yourself, or ask someone who manages them."
    end

    private

    def shared?(access_mode, collection_mode) = access_mode.to_s != "creator_only" && collection_mode.to_s == "fixed"
  end
end
