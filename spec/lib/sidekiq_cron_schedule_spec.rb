require_relative '../../lib/sidekiq_cron_schedule'

RSpec.describe SidekiqCronSchedule do
  subject { described_class.new(default_jobs) }

  let(:default_jobs) do
    {
      "test_job" => {
        "cron" => "0/10 * * * *",
        "class" => "TestJob",
        "args" => %w[one two],
        "description" => "Test job",
        "status" => "enabled",
      },
    }
  end

  describe "#load!" do
    before do
      allow(Sidekiq::Cron::Job).to receive(:destroy_all!)
      allow(Sidekiq::Cron::Job).to receive(:load_from_hash)
      allow(ENV).to receive(:fetch).and_call_original
    end

    it "removes existing jobs" do
      subject.load!
      expect(Sidekiq::Cron::Job).to have_received(:destroy_all!)
    end

    it "loads jobs" do
      subject.load!
      expect(Sidekiq::Cron::Job).to have_received(:load_from_hash).with(default_jobs)
    end

    context "when default jobs are disabled" do
      before do
        allow(ENV).to receive(:fetch).with("CONFIGURE_DEFAULT_JOBS", anything).and_return("false")
      end

      it "loads no jobs" do
        subject.load!
        expect(Sidekiq::Cron::Job).not_to have_received(:load_from_hash)
      end
    end

    context "when jobs env var is specified" do
      let(:env_jobs) do
        {
          "env_test_job" => {
            "cron" => "0/10 * * * *",
            "class" => "EnvTestJob",
            "args" => %w[one three],
            "description" => "Test job",
            "status" => "enabled",
          },
        }
      end

      before do
        allow(ENV).to receive(:fetch).with("SIDEKIQ_CRON", anything).and_return(env_jobs.to_json)
      end

      it "loads jobs" do
        subject.load!
        expect(Sidekiq::Cron::Job).to have_received(:load_from_hash).with(
          default_jobs.merge(env_jobs)
        )
      end

      context "when default jobs are disabled" do
        before do
          allow(ENV).to receive(:fetch).with("CONFIGURE_DEFAULT_JOBS", anything).and_return("false")
        end

        it "only loads env jobs" do
          subject.load!
          expect(Sidekiq::Cron::Job).to have_received(:load_from_hash).with(env_jobs)
        end
      end
    end
  end
end
