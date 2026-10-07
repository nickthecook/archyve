require "rails_helper"

RSpec.describe ApiCall do
  describe ".recording?" do
    subject(:recording) { described_class.recording? }

    # Pinned rather than left to the ambient environment: whoever runs the suite
    # may well have ARCHYVE_RECORD_API_CALLS set for their own debugging.
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ARCHYVE_RECORD_API_CALLS", nil).and_return(env_var)
    end

    let(:env_var) { nil }

    context "with nothing set" do
      it "is off, so a deployment that never asked for this records nothing" do
        expect(recording).to be(false)
      end
    end

    context "when the env var asks for it" do
      let(:env_var) { "true" }

      it { is_expected.to be(true) }
    end

    context "when the env var is set to something false" do
      let(:env_var) { "0" }

      it { is_expected.to be(false) }
    end

    context "when a row disagrees with the env var" do
      let(:env_var) { "true" }

      before { Setting["debug.record_api_calls"] = false }

      it "lets the row win, which is how it is switched off at runtime" do
        expect(recording).to be(false)
      end
    end

    context "when a setting row turns it on" do
      before { Setting["debug.record_api_calls"] = true }

      it { is_expected.to be(true) }
    end

    context "when a setting row turns it back off" do
      before { Setting["debug.record_api_calls"] = false }

      it { is_expected.to be(false) }
    end

    context "when the settings table cannot be read" do
      before { allow(Setting).to receive(:record_api_calls?).and_raise(ActiveRecord::StatementInvalid, "no table") }

      it "is off rather than raising inside the call it observes" do
        expect(recording).to be(false)
      end
    end
  end

  describe ".no_response_code_for" do
    subject(:code) { described_class.no_response_code_for(error) }

    context "with a refused connection" do
      let(:error) { Faraday::ConnectionFailed.new(Errno::ECONNREFUSED.new("refused")) }

      it { is_expected.to eq(described_class::NO_RESPONSE[:connection_refused]) }
    end

    context "with an unresolvable host" do
      let(:error) { Faraday::ConnectionFailed.new(SocketError.new("getaddrinfo failed")) }

      it { is_expected.to eq(described_class::NO_RESPONSE[:dns_failure]) }
    end

    context "with an unreachable host" do
      let(:error) { Faraday::ConnectionFailed.new(Errno::EHOSTUNREACH.new("no route")) }

      it { is_expected.to eq(described_class::NO_RESPONSE[:host_unreachable]) }
    end

    context "with a connection failure Faraday did not explain" do
      let(:error) { Faraday::ConnectionFailed.new("something went wrong") }

      it "falls back rather than guessing, since wrapped_exception is nil" do
        expect(code).to eq(described_class::NO_RESPONSE[:connection_failed])
      end
    end

    context "with a timeout" do
      let(:error) { Faraday::TimeoutError.new("timed out") }

      it { is_expected.to eq(described_class::NO_RESPONSE[:timeout]) }
    end

    context "with a TLS failure" do
      let(:error) { Faraday::SSLError.new("certificate verify failed") }

      it { is_expected.to eq(described_class::NO_RESPONSE[:ssl_failure]) }
    end

    context "with something unrecognised" do
      let(:error) { RuntimeError.new("who knows") }

      it { is_expected.to eq(described_class::NO_RESPONSE[:unknown]) }
    end

    it "never collides with a real HTTP status" do
      expect(described_class::NO_RESPONSE.values).to all(be < described_class::LOWEST_HTTP_STATUS)
    end
  end

  describe "an outcome" do
    subject(:api_call) { described_class.new(response_code: response_code) }

    context "when the server answered" do
      let(:response_code) { 200 }

      it { is_expected.to be_answered }

      it "has no failure" do
        expect(api_call.failure).to be_nil
      end
    end

    context "when the server answered with an error status" do
      let(:response_code) { 503 }

      it "still counts as answered — a refusal is not an outage" do
        expect(api_call).to be_answered
      end
    end

    context "when nothing answered" do
      let(:response_code) { described_class::NO_RESPONSE[:timeout] }

      it { is_expected.not_to be_answered }

      it "names the failure" do
        expect(api_call.failure).to eq(:timeout)
      end

      it "answers the matching predicate" do
        expect(api_call).to be_timeout
      end

      it "does not answer another one" do
        expect(api_call).not_to be_connection_refused
      end
    end

    context "when recording never reached an outcome" do
      let(:response_code) { nil }

      it { is_expected.not_to be_answered }

      it "has no failure to name" do
        expect(api_call.failure).to be_nil
      end
    end
  end

  describe "scoping by outcome" do
    let(:attributes) { { service_name: "vllm", kind: "chat", http_method: "post", url: "http://llm.test" } }
    let!(:answered) { described_class.create!(**attributes, response_code: 200) }
    let!(:timed_out) { described_class.create!(**attributes, response_code: described_class::NO_RESPONSE[:timeout]) }

    it "finds answered calls" do
      expect(described_class.answered).to contain_exactly(answered)
    end

    it "finds calls nothing answered" do
      expect(described_class.unanswered).to contain_exactly(timed_out)
    end

    it "finds one kind of failure" do
      expect(described_class.timeout).to contain_exactly(timed_out)
    end
  end

  describe ".expired" do
    subject(:expired) { described_class.expired }

    let(:attributes) { { service_name: "vllm", kind: "chat", http_method: "post", url: "http://llm.test" } }
    let!(:old) { described_class.create!(**attributes, created_at: (described_class::RETENTION + 1.hour).ago) }

    context "with a row inside the retention window" do
      let!(:fresh) { described_class.create!(**attributes) }

      it "excludes it" do
        expect(expired).not_to include(fresh)
      end

      it "includes the expired one" do
        expect(expired).to include(old)
      end
    end
  end
end
