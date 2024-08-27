RSpec.describe Api::ChatResponse do
  subject { described_class.new(prompt, model:, api_client:, augment:, collections:) }

  let(:prompt) { 'What do I like?' }
  let(:model) { "mixalot:99b" }
  let(:api_client) { create(:client) }
  let(:augment) { false }
  let(:collections) { nil }

  let(:search_double) { instance_double(Search::SearchN, search: search_hits) }
  let(:search_hits) do
    [
      Search::SearchHit.new("I like", 200.0, chunk: chunks[0]),
      Search::SearchHit.new("big chunks", 210.0, chunk: chunks[1]),
      Search::SearchHit.new("and I cannot lie", 220.0, chunk: chunks[2]),
    ]
  end
  let(:chunks) { create_list(:chunk, 3, document:) }
  let(:document) { create(:document, collection:) }
  let(:collection) { create(:collection, name: "90s rap") }
  let(:client_double) do
    instance_double(LlmClients::Ollama::Client, clean_stats: "stats", stats: [])
  end
  let(:completion_response) { "You like no bugs." }
  let(:prompt_augmentor) { instance_double(PromptAugmentor, prompt: augmented_prompt, augment: nil) }
  let(:augmented_prompt) do
    <<~PROMPT
      Here is some context that may help you answer the following question:

      I like

      no bugs

      and I cannot lie

      Question: What do I like?
    PROMPT
  end

  before do
    allow(Search::SearchN).to receive(:new) { search_double }
    allow(LlmClients::Ollama::Client).to receive(:new) { client_double }
    allow(client_double).to receive(:complete).and_return(completion_response)
    allow(PromptAugmentor).to receive(:new) { prompt_augmentor }

    create(:model_config, name: "mixalot:99b")
    create(:model_server)
    create(:collection, name: "smooth jazz")
  end

  describe "#respond" do
    it "returns the reply" do
      expect(subject.respond).to eq({ reply: "You like no bugs.", augmented: false, statistics: "stats" })
    end

    it "calls the client to complete the prompt" do
      subject.respond
      expect(client_double).to have_received(:complete).with("What do I like?")
    end

    context "when augment is true" do
      let(:augment) { true }

      it "returns 'augmented: true' in the response" do
        expect(subject.respond[:augmented]).to be true
      end

      it "calls the client with the augmented prompt" do
        subject.respond
        expect(client_double).to have_received(:complete).with(augmented_prompt)
      end

      it "searches all collections" do
        subject.respond
        expect(Search::SearchN).to have_received(:new) do |params|
          expect(params.length).to eq(2)
          expect(params.map(&:name)).to contain_exactly("90s rap", "smooth jazz")
        end
      end

      context "when collections are given" do
        let(:collections) { [collection] }

        it "searches only the given collections" do
          subject.respond
          expect(Search::SearchN).to have_received(:new) do |params|
            expect(params.length).to eq(1)
            expect(params.first.name).to eq("90s rap")
          end
        end
      end
    end
  end
end
