# frozen_string_literal: true

module Retrieval
  # A fixed-set agent's corpus: exactly its own collections, with no filter on
  # the person chatting. Giving an agent a collection shares it with everyone
  # who may use the agent. Same interface as Retrieval::Corpus.
  class FixedCorpus
    def initialize(agent)
      @agent = agent
    end

    def label = @agent.collections.order(:name).map(&:name).to_sentence.presence || "no collections"

    # Never empty: Search reads an empty list as unrestricted.
    def filters = [documents.select(:id)]

    def documents = Document.in_collections(collections)

    def collections = Collection.where(id: @agent.agent_collections.select(:collection_id))
  end
end
