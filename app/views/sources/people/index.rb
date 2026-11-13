# frozen_string_literal: true

# Who may manage one source. Note what is *not* here: which collections the
# source feeds. That belongs to the collection, because it decides what the
# collection's readers see — see SourcesController#selected_collections.
class Views::Sources::People::Index < Views::Base
  # `accessor` is not "may read this source" — it is "may draw on it": enough to
  # feed it into a collection you manage, without touching its settings or its
  # credentials. That split is what lets IT own the source and a team own what
  # their collection pulls from.
  ACCESS = {
    "accessor" => "Feed it into collections they administer",
    "editor" => "…and change its settings and sync it",
    "manager" => "…and manage its people, and delete it"
  }.freeze

  def initialize(source:, grants:, candidates:, group_grants:, group_candidates:)
    @source = source
    @grants = grants
    @candidates = candidates
    @group_grants = group_grants
    @group_candidates = group_candidates
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
      access: ACCESS,
      create_path: source_people_path(@source),
      member_path: ->(grant) { source_person_path(@source, grant) }
    )

    h2(class: "mt-12 mb-3 text-sm font-medium text-fg") { "Groups" }
    render Views::People::Panel.new(
      subject: @source,
      grants: @group_grants,
      candidates: @group_candidates,
      access: ACCESS,
      create_path: source_groups_path(@source),
      member_path: ->(grant) { source_group_path(@source, grant) },
      grantee: :group
    )
  end

  private

  def page_title = "People · #{@source.name}"

  def kind_chip(label)
    span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { label }
  end
end
