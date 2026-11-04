require "rails_helper"

RSpec.describe Agent do
  describe ".seed_built_ins!" do
    subject(:seed) { described_class.seed_built_ins! }

    let(:archivist) { described_class.archivist }

    it "creates every built-in once" do
      expect { seed }.not_to change(described_class, :count)
    end

    it "marks them built in" do
      seed
      expect(archivist).to be_built_in
    end

    context "when a built-in's prompt has drifted from the code" do
      before { described_class.archivist.update!(prompt: "Something an admin typed.") }

      it "rewrites it" do
        seed
        expect(archivist.prompt).to eq(described_class::BUILT_INS.dig("archivist", :prompt))
      end
    end

    context "when a built-in is missing" do
      before { described_class.archivist.destroy! }

      it "recreates it" do
        expect { seed }.to change(described_class, :count).by(1)
      end
    end
  end
end
