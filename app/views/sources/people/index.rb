# frozen_string_literal: true

# Who may manage one source. Note what is *not* here: which collections the
# source feeds. That belongs to the collection, because it decides what the
# collection's readers see — see SourcesController#selected_collections.
class Views::Sources::People::Index < Views::Base
  # `visitor` is not "may read this source" — it is "may draw on it": enough to
  # feed it into a collection you administer, without touching its settings or
  # its credentials. That split is what lets IT own the source and a team own
  # what their collection pulls from.
  ROLES = {
    "visitor" => "Feed it into collections they administer",
    "curator" => "…and change its settings and sync it",
    "admin" => "…and manage its people, and delete it"
  }.freeze

  def initialize(source:, grants:, candidates:)
    @source = source
    @grants = grants
    @candidates = candidates
  end

  def view_template
    breadcrumb(
      ["Collections", collections_path],
      ["Sources", sources_path],
      [@source.name, source_path(@source)],
      "People"
    )

    header(class: "mb-7") do
      div(class: "flex items-center gap-2") do
        h1(class: "text-2xl font-semibold tracking-tight") { "People" }
        kind_chip("Source")
      end
      p(class: "mt-1 text-sm text-muted") do
        "Who can manage “#{@source.name}”. Which collections it feeds is decided by those collections, not here."
      end
    end

    render Views::People::Panel.new(
      subject: @source,
      grants: @grants,
      candidates: @candidates,
      roles: ROLES,
      create_path: source_people_path(@source),
      member_path: ->(grant) { source_person_path(@source, grant) }
    )
  end

  private

  def page_title = "People · #{@source.name}"

  def kind_chip(label)
    span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { label }
  end
end
