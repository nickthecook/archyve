class SearchBroadcaster
  def initialize(collections, dom_id)
    @collections = collections
    @dom_id = dom_id
  end

  def search(query)
    search_multiple.search(query) do |hit|
      broadcast_hit(hit)
    end
  rescue StandardError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    broadcast_error(e)
  end

  private

  def broadcast_hit(hit)
    Turbo::StreamsChannel.broadcast_append_to(
      "collections",
      target: @dom_id,
      partial: "collections/search_chunk",
      locals: {
        chunk: hit.chunk,
        distance: hit.distance,
        distance_increase_ratio: hit.distance_increase_ratio,
        relevant: hit.relevant,
      }
    )
  end

  def broadcast_error(exception)
    Turbo::StreamsChannel.broadcast_append_to(
      "collections",
      target: @dom_id,
      partial: "shared/search_error", locals: { error: "An error occurred: #{exception}" }
    )
  end

  def search_multiple
    @search_multiple ||= Search::SearchMultiple.new(@collections, include_irrelevant: true)
  end
end
