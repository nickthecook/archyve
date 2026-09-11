# frozen_string_literal: true

class Views::Settings::Index < Views::Base
  def initialize(people_count:, server_count:, model_count:)
    @people_count = people_count
    @server_count = server_count
    @model_count = model_count
  end

  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Settings" }
      p(class: "mt-1 text-sm text-muted") { "Models, inference servers, and preferences." }
    end

    # Links out of this page, so they wear the rail. Two is the most this zone
    # should hold — see the accent budget in docs/design.md.
    div(class: "flex flex-col gap-3") do
      render Views::Doorway.new(
        href: settings_users_path,
        title: "People",
        description: "Who can sign in, and how much of Archyve they see.",
        meta: "#{@people_count} #{'person'.pluralize(@people_count)}"
      ) { people_icon }

      render Views::Doorway.new(
        href: settings_inference_servers_path,
        title: "Inference",
        description: "Where Archyve sends prompts, and which models it may use.",
        meta: inference_meta
      ) { server_icon }
    end
  end

  private

  def page_title = "Settings"

  # A fresh install has nothing configured, and the doorway should say so rather
  # than read "0 servers" as though that were a quantity.
  def inference_meta
    return "not configured" if @server_count.zero?

    "#{@server_count} #{'server'.pluralize(@server_count)} · #{@model_count} #{'model'.pluralize(@model_count)}"
  end

  def people_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.circle(cx: "9", cy: "8", r: "3.2")
      s.path(d: "M3.5 19a5.5 5.5 0 0 1 11 0")
      s.path(d: "M16 5.6a3.2 3.2 0 0 1 0 4.8M17.5 13.4A5.5 5.5 0 0 1 20.5 19")
    end
  end

  def server_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.rect(x: "3", y: "4", width: "18", height: "7", rx: "1.6")
      s.rect(x: "3", y: "13", width: "18", height: "7", rx: "1.6")
      s.path(d: "M6.5 7.5h.01M6.5 16.5h.01")
    end
  end
end
