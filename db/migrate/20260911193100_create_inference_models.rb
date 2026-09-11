class CreateInferenceModels < ActiveRecord::Migration[8.1]
  def change
    # One model Archyve may use, on one server. Named for what it is rather
    # than LanguageModel: vision, audio and rerank models are the same kind of
    # record, and `kind` is expected to grow.
    create_table :inference_models do |t|
      t.references :inference_server, null: false, foreign_key: true

      # The id the provider itself knows — "gemma4:latest", "gpt-4o". Sent
      # verbatim, so it has to match the provider's spelling exactly, which is
      # the whole argument for discovering it rather than typing it.
      t.string :name, null: false
      t.string :display_name

      t.integer :kind, null: false, default: 0 # chat; see InferenceModel.kinds

      # Embedding models only, and validated against the width of the
      # embeddings.embedding column — a vector(768) with one cosine HNSW index
      # physically cannot hold anything else.
      t.integer :dimensions

      t.integer :context_window

      # Whether the model can call tools. Archyve's retrieval is exposed to the
      # model as a tool rather than stuffed into the prompt, so a chat model
      # without this can't do the one thing chat is for.
      t.boolean :supports_tools, null: false, default: false

      t.boolean :enabled, null: false, default: true

      # The chat model offered first. Chat reads this on day one.
      t.boolean :preferred, null: false, default: false

      t.timestamps
    end

    add_index :inference_models, [:inference_server_id, :name], unique: true

    # Both rules that must not be violable by a racing request live in the
    # database, not only in validations.
    add_index :inference_models, :preferred,
      unique: true, where: "preferred AND kind = 0", name: "index_inference_models_on_preferred_chat"

    # Embeddings from different models aren't comparable, so the corpus has
    # exactly one embedder. See InferenceModel#corpus_is_empty for the rest of
    # the story: it can't be *changed* once there are vectors it would strand.
    add_index :inference_models, :kind,
      unique: true, where: "kind = 1", name: "index_inference_models_on_single_embedding"
  end
end
