# frozen_string_literal: true

class Views::Settings::Reviews::Index < Views::Base
  include Views::Admin::Formats

  def initialize(page:, turns:, facets:, query:)
    @page = page
    @turns = turns
    @facets = facets
    @query = query
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Review")
    render Views::Admin::Heading.new(
      title: "Review",
      blurb: "What people asked, what came back, and what they thought of it — without saying who asked."
    )

    render Views::Admin::Filters.new(action: settings_review_path, facets: @facets)
    @page.any? ? listing : empty
  end

  private

  def page_title = "Review"

  def listing
    div(class: "flex flex-col gap-3") { @turns.each { card(it) } }
    render Views::Pager.new(page: @page, action: settings_review_path, params: @query)
  end

  def card(turn)
    answer = turn.answer
    a(
      href: settings_review_chat_path(answer.conversation, anchor: Views::Conversations::Message.answer_dom_id(answer)),
      class: "flex flex-col gap-2 rounded-lg border border-line bg-ink/40 px-4 py-3 hover:border-line-2 transition-colors"
    ) do
      p(class: "line-clamp-2 text-sm font-medium text-fg break-words") { turn.question&.text.to_s.truncate(300) }
      answered(answer)
      feedback(answer.feedback)
      p(class: "font-mono text-[0.7rem] text-faint tabular-nums") do
        plain [ago(answer.created_at), answer.inference_model&.label].compact.join(" · ")
      end
    end
  end

  def answered(answer)
    if answer.failed?
      p(class: "text-sm text-red-300 break-words") { answer.error }
    else
      p(class: "line-clamp-3 text-sm text-muted break-words") { answer_text(answer).truncate(500) }
    end
  end

  def answer_text(answer) = answer.segments.select(&:text?).map(&:content).join(" ").squish

  def feedback(feedback)
    return if feedback.nil?

    div(class: "flex items-start gap-2 text-sm") do
      span(class: "grid h-5 w-5 shrink-0 place-items-center text-accent", title: rating_label(feedback)) do
        render Views::Conversations::RatingIcon.new(feedback.rating) if feedback.rating
      end
      p(class: "line-clamp-2 italic text-muted break-words") { feedback.comment } if feedback.comment
    end
  end

  def rating_label(feedback) = feedback.rating && Views::Conversations::RatingIcon::LABELS[feedback.rating.to_sym]

  def empty
    render Views::Admin::Empty.new(
      message: @query.values.any?(&:present?) ? "No answers match." : "No answers yet.",
      hint: "Feedback appears here as people rate answers or comment on them."
    )
  end
end
