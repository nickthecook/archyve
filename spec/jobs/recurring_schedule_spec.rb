require "rails_helper"

# Covers config/initializers/solid_queue_skip_missed_runs.rb. Solid Queue
# reschedules a recurring task from the slot that just ran, so a process that
# lost wall-clock time would otherwise replay every slot it slept through, one
# per 0.1s, until it caught up.
RSpec.describe SolidQueue::Scheduler::RecurringSchedule do
  subject(:schedule) { described_class.new([]) }

  # A stand-in rather than SolidQueue::RecurringTask: the queue schema lives in
  # its own database, which the single-database test config doesn't carry. The
  # schedule only asks a task for these two things before the timer fires.
  let(:task) { Struct.new(:key, :next_time).new("spec_heartbeat", 1.hour.from_now) }

  let(:delay) { schedule.scheduled_tasks[task.key].initial_delay }

  after { schedule.unschedule_tasks }

  describe "#schedule_task" do
    context "with a slot still to come" do
      it "waits for it" do
        schedule.schedule_task(task, run_at: 45.seconds.from_now)

        expect(delay).to be_within(2).of(45)
      end
    end

    context "with a slot the process slept through" do
      it "skips the backlog and takes the next slot" do
        schedule.schedule_task(task, run_at: 3.hours.ago)

        expect(delay).to be_within(2).of(1.hour)
      end
    end
  end
end
