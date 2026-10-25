# frozen_string_literal: true

# Which chat model a new conversation starts on.
#
# Sits at the top of the Inference page without a heading of its own: it is a
# fact about inference rather than about any one server, and the page it is on
# already says so. Deliberately not a card — the server list below is cards, and
# weight comes from being unlike them. See docs/design.md.
class Views::Settings::DefaultModel < Components::Base
  def initialize(models:, selected_id:)
    @models = models
    # A stale id — a model since deleted, disabled, or found not to call tools —
    # reads as no choice at all, which is how InferenceModel.default_chat
    # resolves it too.
    @selected_id = selected_id if models.any? { |model| model.id == selected_id }
  end

  def view_template
    return if @models.empty?

    div(class: "mb-12 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4") do
      div(class: "min-w-0") do
        p(class: "text-sm font-medium text-fg") { Setting.label("chat.default_model_id") }
        p(class: "mt-0.5 text-xs text-faint") { Setting.description("chat.default_model_id") }
      end
      control
    end
  end

  private

  def control
    form(action: settings_default_model_path, method: "post", class: "flex shrink-0 items-center gap-2") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")
      chooser
      button(type: "submit", class: button_class(:solid, "py-1")) { "Save" }
    end
  end

  def chooser
    select(
      name: "inference_model_id",
      aria_label: "Default chat model",
      class: "rounded border border-line bg-void/60 px-2.5 py-1.5 font-mono text-xs text-muted " \
             "outline-none focus:border-accent hover:text-fg transition-colors"
    ) do
      # The way back out. InferenceModel.default_chat picks one on its own when
      # nothing is set, so a setting with no way to unset it would be a door
      # that only opens one way.
      option(value: "", selected: @selected_id.nil?) { "First available" }
      servers.size > 1 ? grouped : @models.each { option_for(it) }
    end
  end

  # Same grouping rule as the chat composer's picker: which server a model is on
  # only matters once there is more than one, and then it matters for all of them.
  def grouped
    @models.group_by(&:inference_server).sort_by { |server, _| server.name }.each do |server, models|
      optgroup(label: server.name) { models.each { option_for(it) } }
    end
  end

  def option_for(model)
    option(value: model.id, selected: model.id == @selected_id) { model.label }
  end

  def servers = @servers ||= @models.map(&:inference_server_id).uniq
end
