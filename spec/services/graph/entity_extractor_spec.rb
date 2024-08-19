RSpec.describe Graph::EntityExtractor do
  subject { described_class.new(model_config, traceable:) }

  let(:chunk_content) do
    <<~CHUNK
      On their left was the precipitous Jersey shore, and on their right the towering buildings of the great city. Over
      the water the late afternoon sun spread a warm, mellow glow and touched with gold the myriad windows of the
      clustering skyscrapers across the river. The man knocked out his pipe with calm deliberation and turned his wide,
      gray eyes to the lofty Palisades, now bathed in a dazzling crimson. Then slowly his glance wandered back to where
      the shimmering light fell across the little shanty on the barge and picked out in hold relief the incongruously new
      and shining letters, _Minnie M. Baxter_. A smile lighted up his lined, weary features, a smile of pride in ownership.
      "She ain't so bad fer the old battle-axe that she is, hey Skippy?" he called to the boy. The boy's tousled head
      appeared from around the battered cabin. "I'll say she ain't, Pop," he answered. "An' she's _ours_! Gee, I can't
      believe my pop really an' truly owns a _whole_ barge!" The man laughed, then listened for a moment to a significant
      sound emanating from the muffled engine.
    CHUNK
  end
  let(:traceable) { nil }
  let(:chunk) { create(:chunk, content: chunk_content) }
  let(:llm_client) { instance_double(LlmClients::Ollama::Client, complete: completion) }
  let(:completion) do
    <<~COMPLETION
      ("entity"|"Minnie M. Baxter"|"organization"|"Minnie M. Baxter is the name of the barge owned by Skippy and his father.")##
      ("entity"|"Skippy"|"person"|"Skippy is a boy who shares his pride in owning the barge with his father.")##
      This line is just here to get skipped.
      ("relationship"|"Skippy"|"Minnie M. Baxter"|"Skippy has an emotional connection to the barge, which is now owned by his father."|5)##
      ##########
      ("entity"|"Bachlava"|"person"|"Bachlava shows up with Xzibit, has him put a fish tank in a Civic.")##
    COMPLETION
  end
  let!(:preexisting_desc) { create(:graph_entity_description, chunk:) }

  include_context "with default models"

  before do
    allow(LlmClients::Ollama::Client).to receive(:new) { llm_client }
  end

  describe "#extract" do
    it "destroys the existing entity descriptions for that chunk" do
      expect(chunk.graph_entity_descriptions).to contain_exactly(preexisting_desc)
      subject.extract(chunk)
      expect(chunk.graph_entity_descriptions).not_to include(preexisting_desc)
    end

    it "creates the correct GraphEntityDescriptions" do
      subject.extract(chunk)
      expect(GraphEntityDescription.all.map(&:description)).to contain_exactly(
        "Skippy is a boy who shares his pride in owning the barge with his father.",
        "Minnie M. Baxter is the name of the barge owned by Skippy and his father."
      )
    end

    it "creates the correction relationship" do
      expect { subject.extract(chunk) }.to change(GraphRelationship, :count).from(0).to(1)
      expect(GraphRelationship.first.from_entity.name).to eq("Skippy")
      expect(GraphRelationship.first.to_entity.name).to eq("Minnie M. Baxter")
    end

    context "when traceable is set" do
      let(:traceable) { "traceable!" }

      it "passes the traceable to the LLM client" do
        subject.extract(chunk)
        expect(LlmClients::Ollama::Client).to have_received(:new).with(hash_including(traceable:))
      end
    end
  end
end
