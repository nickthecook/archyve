require "rails_helper"

# No example for #perform: Solid Queue's tables live in their own database,
# which the single-database test config doesn't carry, so even stubbing the
# model loads a schema that isn't there. What the body does is one delegation
# to the gem; what could go wrong is the queue, below, and the recurring entry
# — see spec/jobs/recurring_entries_spec.rb.
RSpec.describe BackgroundJobs::SweepFinishedJob do
  it "runs on a queue a worker polls" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
