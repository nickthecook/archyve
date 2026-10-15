module Chat
  # Closes turns nothing came back to finish — a worker killed mid-answer, or a
  # job discarded before Chat::Responder ever ran.
  #
  # Chat::Turn#complete! covers every ending the process survives, so this is
  # for the ones it doesn't. Nothing else ever sets `completed_at`, and a turn
  # without one spins on every future load of its conversation.
  class SweepHungTurnsJob < ApplicationJob
    queue_as :default

    def perform
      Message.hung.find_each do |turn|
        Rails.logger.warn("Abandoning hung turn #{turn.id} in conversation #{turn.conversation_id}")

        turn.abandon!
      end
    end
  end
end
