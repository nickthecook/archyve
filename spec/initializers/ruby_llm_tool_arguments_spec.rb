require "rails_helper"

# A patch on RubyLLM's internals, so this drives the real accumulator rather
# than the patch — an upgrade that moves the seam fails here instead of in a
# chat.
RSpec.describe "RubyLLM tool-call arguments" do
  subject(:arguments) { accumulator.to_message(nil).tool_calls.values.sole.arguments }

  let(:accumulator) { RubyLLM::StreamAccumulator.new }

  # How vLLM streams a tool call: the name and id first, then the arguments in
  # fragments keyed by nothing, which the accumulator appends to the call it
  # opened.
  def stream(*fragments)
    accumulator.add(chunk("call_81e7af" => RubyLLM::ToolCall.new(id: "call_81e7af", name: "list_collections",
      arguments: "")))
    fragments.each { |text| accumulator.add(chunk(nil => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: +text))) }
  end

  def chunk(tool_calls) = RubyLLM::Chunk.new(role: :assistant, content: nil, tool_calls:)

  # vLLM 1.5.1 for a tool that declares no parameters. Left alone it is a
  # JSON::ParserError that fails the whole turn.
  context "when the server sends an unclosed brace" do
    before { stream("{") }

    it "reads it as no arguments" do
      expect(arguments).to eq({})
    end
  end

  context "when the server sends a complete object" do
    before { stream('{"slug": ', '"handbook"}') }

    it "parses it" do
      expect(arguments).to eq("slug" => "handbook")
    end
  end

  # Guessing at what the model meant to send would call the tool with arguments
  # it never finished choosing.
  context "when the arguments are truncated mid-value" do
    before { stream('{"slug": "hand') }

    it "still refuses to guess" do
      expect { arguments }.to raise_error(JSON::ParserError)
    end
  end
end
