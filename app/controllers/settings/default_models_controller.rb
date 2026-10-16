module Settings
  # Which chat model a new conversation starts on. Chosen at the top of the
  # Inference page, since it is a fact about inference rather than about any one
  # server — see Setting's "chat.default_model_id".
  class DefaultModelsController < ApplicationController
    require_role :admin

    def update
      id = params[:inference_model_id].presence

      if id.nil?
        Setting.clear("chat.default_model_id")
        return redirect_to settings_inference_servers_path, notice: "Default model cleared."
      end

      # Checked against the list the page offers rather than trusted: a model
      # that can't call tools or isn't enabled would resolve to the fallback
      # anyway, which looks like the setting silently not taking.
      model = InferenceModel.for_chat.find_by(id:)
      return redirect_to(settings_inference_servers_path, alert: "That model can't be the default.") if model.nil?

      Setting["chat.default_model_id"] = model.id
      redirect_to settings_inference_servers_path, notice: "Default model set to #{model.label}."
    end
  end
end
