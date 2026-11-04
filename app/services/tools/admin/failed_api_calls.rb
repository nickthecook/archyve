# frozen_string_literal: true

module Tools
  module Admin
    # Status lines only: request and response bodies carry archive text and
    # headers can carry credentials.
    class FailedApiCalls < Base
      params do
        integer :limit, description: "How many of the most recent failures to show, up to #{MAX_LIMIT}. Defaults to 10.",
          required: false
      end

      def name = "list_failed_api_calls"
      def label = "failed API calls"

      def description
        "List recent recorded API calls that got an error status or no answer at all, newest first. Only " \
          "calls made while recording was switched on are kept, and only for a few days."
      end

      def execute(limit: nil)
        calls = failed.recent.limit(capped(limit, default: 10))

        {
          status: "ok",
          recording_outgoing: ApiCall.recording?,
          recording_incoming: ApiCall.recording_incoming?,
          calls: calls.map { entry(it) }.presence || "none recorded"
        }
      end

      private

      def failed
        ApiCall.where(response_code: [...ApiCall::LOWEST_HTTP_STATUS, 400..]).or(ApiCall.where.not(error: nil))
      end

      def entry(call)
        {
          at: call.created_at.iso8601, direction: call.incoming? ? "incoming" : "outgoing",
          kind: call.kind, service: call.service_name, request: "#{call.http_method} #{path_of(call.url)}",
          outcome: outcome(call), error: call.error, duration_ms: call.duration_ms
        }.compact
      end

      # Query strings can carry keys, so only the host and path are reported.
      def path_of(url)
        uri = URI.parse(url)
        "#{uri.host}#{uri.path}"
      rescue URI::InvalidURIError
        "(unparseable URL)"
      end

      def outcome(call)
        return "HTTP #{call.response_code}" if call.response_code.to_i >= ApiCall::LOWEST_HTTP_STATUS

        ApiCall::NO_RESPONSE.key(call.response_code)&.to_s&.humanize || "no outcome recorded"
      end
    end
  end
end
