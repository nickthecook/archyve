# frozen_string_literal: true

# Who may use one collection, and how much. The counterpart to
# Views::Settings::Users::Index, which is about accounts rather than access.
class Views::Collections::People::Index < Views::Base
  # What a grant means *here*. Deliberately spelled out: "operator" tells you
  # nothing on its own, and this is the screen where the choice is made.
  # Kept honest against what the app can actually do. Collections have no edit
  # or destroy action yet, so "admin" does not promise them; and a `user` grant
  # buys nothing observable until retrieval is scoped to readable collections.
  ROLE_DESCRIPTIONS = {
    "user" => "Chat and search against it",
    "operator" => "…and file documents by hand",
    "admin" => "…and manage its people"
  }.freeze

  def initialize(collection:, grants:, candidates:)
    @collection = collection
    @grants = grants
    @candidates = candidates
  end

  def view_template
    a(href: collection_path(@collection), class: "text-sm text-muted hover:text-fg transition-colors") do
      "← #{@collection.name}"
    end

    header(class: "mt-3 mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "People" }
      p(class: "mt-1 text-sm text-muted") do
        "Who can use “#{@collection.name}”. Someone's account role still caps what a grant here can give them."
      end
    end

    @grants.any? ? grants_list : empty_state
    add_form if @candidates.any?
  end

  private

  def page_title = "People · #{@collection.name}"

  def grants_list
    ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      @grants.each { |grant| row(grant) }
    end
  end

  def row(grant)
    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      div(class: "min-w-0") do
        p(class: "truncate text-sm font-medium text-fg") { grant.user.email_address }
        p(class: "mt-0.5 text-xs text-faint") { capped_note(grant) }
      end
      div(class: "flex shrink-0 items-center gap-3") do
        role_form(grant)
        revoke(grant)
      end
    end
  end

  # The ceiling is invisible otherwise: an admin grant to someone whose account
  # is chat-only reads as a mistake until you know it simply doesn't apply.
  def capped_note(grant)
    effective = grant.user.role_on(@collection)
    if effective.to_s == grant.role
      "#{grant.role.capitalize} here"
    else
      "#{grant.role.capitalize} here, but their account is #{grant.user.role} — so: #{effective}"
    end
  end

  def role_form(grant)
    form(action: collection_person_path(@collection, grant), method: "post", class: "flex items-center gap-4") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")
      select(name: "role", class: select_classes) do
        CollectionUser.roles.each_key do |role|
          option(value: role, selected: grant.role == role) { role.capitalize }
        end
      end
      button(type: "submit", class: "text-xs text-muted hover:text-fg transition-colors cursor-pointer") { "Save" }
    end
  end

  def revoke(grant)
    form(action: collection_person_path(@collection, grant), method: "post", class: "inline") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "delete")
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors cursor-pointer") { "Revoke" }
    end
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-10 text-center") do
      p(class: "text-sm text-muted") { "Nobody has been given access yet." }
      p(class: "mt-1 text-xs text-faint") { "Administrators reach every collection without a grant." }
    end
  end

  def add_form
    h2(class: "mt-8 mb-3 text-sm font-medium text-fg") { "Give someone access" }

    form(action: collection_people_path(@collection), method: "post", class: "flex flex-wrap items-end gap-3 rounded-lg border border-line bg-ink/40 p-5") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

      div(class: "flex-1 basis-48 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "person_user_id") { "Person" }
        select(id: "person_user_id", name: "user_id", class: "w-full #{select_classes}") do
          @candidates.each { |user| option(value: user.id) { user.email_address } }
        end
      end

      div(class: "flex-1 basis-56 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "person_role") { "Access" }
        select(id: "person_role", name: "role", class: "w-full #{select_classes}") do
          CollectionUser.roles.each_key do |role|
            option(value: role) { "#{role.capitalize} — #{ROLE_DESCRIPTIONS[role]}" }
          end
        end
      end

      button(
        type: "submit",
        class: "shrink-0 rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Give access" }
    end
  end

  def select_classes
    "rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg outline-none focus:border-accent transition-colors"
  end
end
