module Search
  class SearchMultiple < Base
    def initialize(collections, dom_id: nil, partial: "collections/search_chunk", num_results: 10)
      @collections = collections
      @dom_id = dom_id
      @partial = partial
      @num_results = num_results

      super()
    end

    # rubocop:disable Metrics/AbcSize
    def search(query)
      hits = searchers.map do |search|
        search.search(query)
      end.flatten.sort_by(&:distance)

      hits.first(@num_results).each do |hit|
        broadcast_hit(hit)
      end
    rescue StandardError => e
      raise if @dom_id.nil?

      Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

      broadcast_error(e)
    end
    # rubocop:enable Metrics/AbcSize

    private

    def broadcast_hit(hit)
      Turbo::StreamsChannel.broadcast_append_to(
        "collections", target: @dom_id, partial: @partial, locals: { chunk: hit.chunk, distance: hit.distance }
      )
    end

    def broadcast_error(exception)
      Turbo::StreamsChannel.broadcast_append_to(
        "collections", target: @dom_id, partial: "shared/search_error", locals: { error: "An error occurred: #{exception}" }
      )
    end

    def searchers
      @searchers ||= @collections.map do |collection|
        Search.new(collection)
      end
    end
  end
end
