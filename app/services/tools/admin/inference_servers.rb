# frozen_string_literal: true

module Tools
  module Admin
    # Reports the last recorded check rather than checking: a check writes to
    # the server row, and these tools only read.
    class InferenceServers < Base
      def name = "check_inference_servers"
      def label = "the inference servers"

      def description
        "List the inference servers, whether each answered when it was last checked and when that was, " \
          "and which chat and embedding models each provides."
      end

      def execute(**)
        servers = InferenceServer.includes(:inference_models).order(:name)
        return { status: "none", instruction: "No inference servers are configured." } if servers.empty?

        { status: "ok", default_chat_model: InferenceModel.default_chat&.label || "none", servers: servers.map { entry(it) } }
      end

      private

      def entry(server)
        {
          name: server.name, type: server.type_label, address: server.base_url,
          last_check: server.checked? ? last_check(server) : "never checked",
          models: server.inference_models.map { model(it) }.join("; ").presence || "none"
        }
      end

      def last_check(server)
        outcome = server.reachable? ? "answered" : "failed: #{server.last_check_error}"
        "#{outcome} (#{server.last_checked_at.iso8601})"
      end

      def model(model)
        flags = [model.kind, ("disabled" unless model.enabled?), ("no tools" if model.chat? && !model.supports_tools?)]
        "#{model.label} (#{flags.compact.join(', ')})"
      end
    end
  end
end
