require "rails_helper"

RSpec.describe ApiCalls::Recorder do
  subject(:recorder) { described_class.new(app, service_name: "vllm") }

  # Stands in for the adapter rather than using Faraday's :test adapter, which
  # has no streaming: this is the only way to drive on_data from a spec.
  # Returning a Response built from a finished env runs on_complete inline.
  let(:app) do
    lambda do |env|
      env.request.on_data&.call(sse, sse.bytesize, env)
      env.status = 200
      env.response_headers = Faraday::Utils::Headers.new("content-type" => "application/json")
      env.body = response_body
      Faraday::Response.new(env)
    end
  end

  let(:sse) { "" }
  let(:response_body) { '{"choices":[{"message":{"content":"hi"}}]}' }
  let(:request_body) { '{"model":"qwen3","messages":[{"role":"user","content":"hi"}]}' }
  let(:path) { "/v1/chat/completions" }

  let(:env) do
    Faraday::Env.from(
      method: :post,
      url: URI("http://llm.test#{path}"),
      body: request_body,
      request_headers: Faraday::Utils::Headers.new(
        "Authorization" => "Bearer sk-secret",
        "Content-Type" => "application/json"
      ),
      request: Faraday::RequestOptions.new
    )
  end

  describe "#call" do
    let(:result) { recorder.call(env) }

    context "when recording is on" do
      before { Setting["debug.record_api_calls"] = true }

      it "records one call" do
        expect { result }.to change(ApiCall, :count).by(1)
      end

      it "returns the response" do
        expect(result.status).to eq(200)
      end

      describe "the recorded row" do
        let(:api_call) { result && ApiCall.last }

        it "names the service" do
          expect(api_call.service_name).to eq("vllm")
        end

        it "classifies the call" do
          expect(api_call.kind).to eq("chat")
        end

        it "keeps the method and url" do
          expect(api_call).to have_attributes(http_method: "post", url: "http://llm.test/v1/chat/completions")
        end

        it "keeps the request body" do
          expect(api_call.request_body["model"]).to eq("qwen3")
        end

        it "keeps the response body" do
          expect(api_call.response_body.dig("choices", 0, "message", "content")).to eq("hi")
        end

        it "records the status" do
          expect(api_call.response_code).to eq(200)
        end

        it "redacts the authorization header" do
          expect(api_call.request_headers["Authorization"]).to eq("[REDACTED]")
        end

        it "keeps non-secret headers" do
          expect(api_call.request_headers["Content-Type"]).to eq("application/json")
        end

        it "is not marked streamed" do
          expect(api_call.streamed).to be(false)
        end
      end

      context "when the response is streamed" do
        let(:sse) { %(data: {"choices":[{"delta":{"reasoning_content":"thinking"}}]}\n\n) }
        # What RubyLLM leaves behind once on_data has consumed the stream, and
        # the reason the recorder tees it.
        let(:response_body) { "" }
        let(:received) { [] }

        before { env.request.on_data = ->(chunk, _bytes, _env) { received << chunk } }

        it "records the teed stream as the response body" do
          result
          expect(ApiCall.last.response_body).to include("reasoning_content")
        end

        it "marks the row streamed" do
          result
          expect(ApiCall.last.streamed).to be(true)
        end

        it "still hands every chunk to the original handler" do
          result
          expect(received).to eq([sse])
        end
      end

      context "when the call raises" do
        let(:app) { ->(_env) { raise Faraday::ConnectionFailed, "refused" } }

        it "records the failure" do
          expect { result rescue nil }.to change(ApiCall, :count).by(1)
        end

        it "keeps the error on the row" do
          result rescue nil
          expect(ApiCall.last.error).to include("Faraday::ConnectionFailed")
        end

        it "re-raises" do
          expect { result }.to raise_error(Faraday::ConnectionFailed)
        end
      end

      context "when the path is not recorded" do
        let(:path) { "/v1/embeddings" }

        it "records nothing" do
          expect { result }.not_to change(ApiCall, :count)
        end

        it "still returns the response" do
          expect(result.status).to eq(200)
        end
      end

      context "when the call belongs to something traceable" do
        let(:conversation) { create(:conversation) }

        before { Current.api_call_traceable = conversation }

        it "files the row under it" do
          result
          expect(ApiCall.last.traceable).to eq(conversation)
        end
      end

      context "when writing the row fails" do
        before { allow(ApiCall).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "boom") }

        it "does not break the call" do
          expect(result.status).to eq(200)
        end
      end
    end

    context "when recording is off" do
      before { Setting["debug.record_api_calls"] = false }

      it "records nothing" do
        expect { result }.not_to change(ApiCall, :count)
      end

      it "still returns the response" do
        expect(result.status).to eq(200)
      end
    end
  end
end
