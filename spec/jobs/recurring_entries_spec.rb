require "rails_helper"

# config/recurring.yml is data, not code: a task naming a class that doesn't
# exist, or a queue nothing works, fails silently inside the scheduler at
# runtime — the job simply never runs, in production, with no error anyone sees.
RSpec.describe "config/recurring.yml" do
  # `command:` tasks evaluate Ruby instead of naming a job class, so they have
  # nothing to constantize. Only `class:` entries are checked here.
  def entries_for(environment)
    config = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch(environment)
    config.select { |_key, task| task.key?("class") }
  end

  %w[development production].each do |environment|
    context "in #{environment}" do
      subject(:entries) { entries_for(environment) }

      it "names classes that exist" do
        expect { entries.each_value { it.fetch("class").constantize } }.not_to raise_error
      end

      it "names classes that are jobs" do
        klasses = entries.values.map { it.fetch("class").constantize }
        expect(klasses).to all(be < ActiveJob::Base)
      end

      it "gives every task a schedule" do
        expect(entries.values).to all(include("schedule"))
      end
    end
  end

  it "schedules the inference check" do
    expect(entries_for("production")).to include("enqueue_due_inference_checks")
  end
end
