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
  # `caption` names the choice, which the composer needs — several controls sit
  # in that row and each has to say what it is. The corridor passes nil: its
  # field says "Ask your archive" one line above, so saying it again is the
  # furniture that landing is trying not to have.
  def initialize(models:, selected: nil, caption: "Ask")
    @models = models
    @selected = selected
    @caption = caption
  end

  def view_template
    return if @models.empty?

    label(class: "flex items-center gap-2") do
      span(class: "text-[0.7rem] uppercase tracking-[0.12em] text-faint") { @caption } if @caption
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
      # 70%, not 60%: on the landing this floats over the lit corridor, and the
      # rings bleeding through were enough to make the model name hard to read.
      class: "rounded border border-line bg-void/70 px-2.5 py-1 font-mono text-xs text-muted " \
             "outline-none focus:border-accent hover:text-fg transition-colors"
    ) do
      servers.size > 1 ? grouped : @models.each { option_for(it) }
    end
  end

  # Which server a model is on only matters once there is more than one of them,
  # and then it matters for every model: two servers can be worth choosing
  # between on latency or cost alone. Grouping says it once per server rather
  # than repeating it down every option.
  def grouped
    @models.group_by(&:inference_server).sort_by { |server, _| server.name }.each do |server, models|
      optgroup(label: server.name) { models.each { option_for(it) } }
    end
  end

  def option_for(model)
    option(value: model.id, selected: model.id == @selected&.id) { model.label }
  end

  def servers = @servers ||= @models.map(&:inference_server_id).uniq

  def named(model)
    span(class: "font-mono text-xs text-muted") { model.label }
  end
end
