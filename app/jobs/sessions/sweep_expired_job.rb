module Sessions
  # Sessions expire by age on lookup (Session.active), so this only stops the
  # table growing without bound. Session::LIFETIME is the age.
  class SweepExpiredJob < ApplicationJob
    queue_as :default

    def perform
      Session.expired.in_batches.delete_all
    end
  end
end
