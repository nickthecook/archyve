require "rails_helper"

# config/recurring.yml is data, not code: a task naming a class that doesn't
# exist, or a queue nothing works, fails silently inside the scheduler at
# runtime — the job simply never runs, in production, with no error anyone sees.
RSpec.describe "config/recurring.yml" do
  def entries_for(environment)
    YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch(environment)
  end

  # Queues a worker in config/queue.yml actually polls. `*` and `prefix*` are
  # Solid Queue's wildcards — see SolidQueue::QueueSelector.
  def worked_queues
    config = YAML.load(ERB.new(Rails.root.join("config/queue.yml").read).result, aliases: true)
    config.fetch("default").fetch("workers").flat_map { Array(it.fetch("queues")) }
  end

  def worked?(queue)
    worked_queues.any? { it == "*" || it == queue || (it.end_with?("*") && queue.start_with?(it.chomp("*"))) }
  end

  %w[development production].each do |environment|
    context "in #{environment}" do
      subject(:entries) { entries_for(environment) }

      # Only the classed entries, so a stray `command:` fails one example with
      # something readable instead of raising KeyError in every example below.
      let(:classed) { entries.values.select { it.key?("class") } }

      # A `command:` task has no job class, so it lands on Solid Queue's own
      # solid_queue_recurring queue rather than one of ours — which no worker
      # polls. That stranded the session sweep for 17 days. Naming a class makes
      # the queue impossible to get wrong, so none are allowed.
      it "names a class rather than a command" do
        expect(entries.values).to all(include("class"))
      end

      it "names classes that exist" do
        expect { classed.each { it.fetch("class").constantize } }.not_to raise_error
      end

      it "names classes that are jobs" do
        expect(classed.map { it.fetch("class").constantize }).to all(be < ActiveJob::Base)
      end

      it "gives every task a schedule" do
        expect(entries.values).to all(include("schedule"))
      end

      # The effective queue, not the declared one: a task may omit `queue:` and
      # take whatever its class declares with `queue_as`.
      it "sends every task to a queue a worker polls" do
        queues = classed.map { it["queue"] || it.fetch("class").constantize.new.queue_name }

        expect(queues).to all(satisfy { worked?(it) })
      end
    end
  end

  it "schedules the inference check" do
    expect(entries_for("production")).to include("enqueue_due_inference_checks")
  end
end
