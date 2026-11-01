# frozen_string_literal: true

# Who may use one collection. The panel itself is shared with the source
# equivalent — see Views::People::Panel.
class Views::Collections::People::Index < Views::Base
  ROLES = {
    "visitor" =>"Chat and search against it",
    "curator" => "…and file documents by hand",
    "admin" => "…and manage its people"
  }.freeze

  def initialize(collection:, grants:, candidates:)
    @collection = collection
    @grants = grants
    @candidates = candidates
  end

  def view_template
    breadcrumb(["Collections", collections_path], [@collection.name, collection_path(@collection)], "People")

    header(class: "mb-7") do
      div(class: "flex items-center gap-2") do
        h1(class: "text-2xl font-semibold tracking-tight") { "People" }
        kind_chip("Collection")
      end
      p(class: "mt-1 text-sm text-muted") do
        "Who can use “#{@collection.name}”. Someone's account role still caps what a grant here can give them."
      end
    end

    render Views::People::Panel.new(
      subject: @collection,
      grants: @grants,
      candidates: @candidates,
      roles: ROLES,
      create_path: collection_people_path(@collection),
      member_path: ->(grant) { collection_person_path(@collection, grant) }
    )
  end

  private

  def page_title = "People · #{@collection.name}"

  def kind_chip(label)
    span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { label }
  end
end
