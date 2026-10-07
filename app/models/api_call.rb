# One outbound HTTP call, recorded so a provider that isn't behaving can be
# inspected after the fact — what Archyve actually sent, and what came back on
# the wire rather than after a client library has interpreted it.
#
# Written by ApiCalls::Recorder, which sits in the Faraday stack of both RubyLLM
# and Http.connection but stays inert unless recording is switched on. See
# Setting's "debug.record_api_calls" for how that happens.
class ApiCall < ApplicationRecord
  # What a call was for. An allowlist rather than a label on everything — see
  # ApiCalls::Kind for what is deliberately not recorded.
  KINDS = %w[chat discovery].freeze

  # Rows are debugging exhaust carrying request and response bodies, so they
  # expire on a timer. ApiCalls::SweepExpiredJob does the deleting.
  RETENTION = 3.days

  # Usually the turn a chat call was answering, which is the difference between
  # a list of calls and being able to ask what one conversation did.
  belongs_to :traceable, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }

  scope :expired, -> { where(created_at: ...RETENTION.ago) }
  scope :recent, -> { order(created_at: :desc) }

  # Rescued because this is asked on every outbound call, including ones made
  # before the schema is loaded — a missing settings table must not take down
  # the request it is only trying to observe.
  def self.recording?
    Setting.record_api_calls?
  rescue StandardError
    false
  end
end
