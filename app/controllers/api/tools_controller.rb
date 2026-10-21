module Api
  class ToolsController < BaseController
    # Per key, since a search is an embedding call and a vector scan.
    CALLS_PER_MINUTE = 60

    rate_limit to: CALLS_PER_MINUTE, within: 1.minute, only: :run, by: -> { Current.api_key.id },
      with: -> { render_error :too_many_requests, "rate_limited", "Too many tool calls. Try again in a minute." }

    def index
      render json: { tools: Tools.all.map(&:definition) }
    end

    def run
      tool = Tools.find(request.path_parameters[:name])
      return render_error(:not_found, "not_found", "No such tool.") if tool.nil?

      arguments = parsed_body
      return render_error(:bad_request, "invalid_json", "The request body isn't valid JSON.") if arguments.nil?

      result = tool.new(user: Current.user).call(arguments)
      render json: result.body, status: result.status
    end

    private

    # Rescued here rather than with rescue_from, which runs outside the around
    # action that records the call and would leave it recorded as a 500.
    def parsed_body
      request.request_parameters.to_hash
    rescue ActionDispatch::Http::Parameters::ParseError
      nil
    end
  end
end
