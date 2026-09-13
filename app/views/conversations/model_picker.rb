# frozen_string_literal: true

# Which model answers, chosen where the question is asked.
#
# It sits in the composer rather than in a settings page because it is a
# property of the *asking*, not of the app: a cheap fast model for "what does
# the handbook say", a bigger one for "compare these two procedures". Picking
# one is sticky from that question on — see Chat::Ask.
#
# Rendered as a plain select, because unlike scope this is a choice of exactly
# one and a model list has no state to show — the chip vocabulary the scope
# picker uses would be all cost and no benefit. With a single model configured
# it degrades to a label: there is nothing to choose, but still something worth
# saying about which model is about to answer.
class Views::Conversations::ModelPicker < Components::Base
  def initialize(models:, selected: nil)
    @models = models
    @selected = selected
  end

  def view_template
    return if @models.empty?

    label(class: "flex items-center gap-2") do
      span(class: "text-[0.7rem] uppercase tracking-[0.12em] text-faint") { "Ask" }
      # With one model there is nothing to choose, but there is still something
      # to say: which model is about to answer. A select of one is a control
      # that can only disappoint, so it becomes a label instead.
      @models.size > 1 ? chooser : named(@selected || @models.first)
    end
  end

  private

  def chooser
    select(
      name: "inference_model_id",
      class: "rounded border border-line bg-void/60 px-2.5 py-1 text-xs text-muted " \
             "outline-none focus:border-accent hover:text-fg transition-colors"
    ) do
      @models.each do |model|
        option(value: model.id, selected: model.id == @selected&.id) { model.label }
      end
    end
  end

  def named(model)
    span(class: "font-mono text-xs text-muted") { model.label }
  end
end
