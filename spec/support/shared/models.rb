RSpec.shared_context "with default models" do
  let(:model_config) { create(:model_config, model_server:) }
  let(:embedding_model_config) do
    create(:model_config, name: "nomic-embed-text", model: "nomic-embed-text", model_server:, embedding: true)
  end
  let(:model_server) { create(:model_server) }

  before do
    model_config.make_default_chat_model
    model_config.make_active_summarization_model
    model_config.make_active_entity_extraction_model
    embedding_model_config.make_active_embedding_model
  end
end
