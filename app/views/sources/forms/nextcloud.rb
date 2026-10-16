# frozen_string_literal: true

# The folder picker browses one directory at a time, because Nextcloud refuses
# `Depth: infinity` on PROPFIND — there is no call that lists a whole tree.
#
# Every control is a GET submit button on the form itself, the trick
# Views::Sources::Forms::Bookstack uses for its Browse button: the form
# serializes into the query string, so navigating keeps the ticks and anything
# typed. No JavaScript, because the listing was always a round trip.
class Views::Sources::Forms::Nextcloud < Views::Sources::Form
  def self.new_heading = "Add a Nextcloud server"

  def self.new_blurb
    "Archyve reads the folders you pick, including everything in their subfolders, and keeps the archive matching them."
  end

  def self.edit_blurb
    "Unticking a folder doesn't delete anything you filed by hand: its files stop being fed, and the ones only this source put in a collection are retired."
  end

  private

  def type_fields
    field("Folders to sync", "Browse in and tick as many as you like. Everything inside is taken, and stays in step as files are added and removed.") do
      folder_picker
    end
  end

  def new_server_hint
    "The server, and the user Archyve reads it as. Archyve sees that user's files, plus whatever is shared with them."
  end

  # Only this type and BookStack need one: the listing comes from a live call, so
  # changing server has to re-list what is on it.
  def server_extras = browse_button

  def browse_button
    browse_to(nil, "Browse", css: button_class(:quiet, "shrink-0"))
  end

  def folder_picker
    return no_server if @source.endpoint.blank?
    return catalogue_error if @catalogue&.error

    # Unticking everything has to submit an empty list rather than omitting the
    # key, or "sync nothing" would read as "leave it as it was".
    input(type: "hidden", name: "source[folders][]", value: "")

    div(class: "flex flex-col gap-3") do
      elsewhere_chips
      breadcrumb
      listing
    end
  end

  # Folders picked somewhere other than the directory on screen. They are
  # checkboxes like any other row — unticking one is how you drop it — but they
  # have to be rendered here too, because a checkbox that isn't in the document
  # submits nothing and navigating would silently forget it.
  def elsewhere_chips
    away = picked - [here, *directories.map(&:path)]
    return if away.empty?

    div(class: "flex flex-wrap gap-1.5") do
      away.each { |folder| chip(folder) }
    end
  end

  def chip(folder)
    label(
      class: "flex cursor-pointer items-center gap-1.5 rounded border border-line bg-void/40 px-2 py-1 " \
        "text-xs text-muted hover:text-fg hover:border-line-2 transition-colors"
    ) do
      input(type: "checkbox", name: "source[folders][]", value: folder, checked: true, class: "h-3 w-3 accent-accent")
      span(class: "font-mono") { folder }
    end
  end

  def breadcrumb
    div(class: "flex flex-wrap items-center gap-1 text-xs text-muted") do
      crumbs.each_with_index do |(label_text, path), index|
        span(class: "text-faint") { "›" } if index.positive?

        if path == here
          span(class: "text-fg") { label_text }
        else
          browse_to(path, label_text, css: "text-muted hover:text-accent transition-colors")
        end
      end
    end
  end

  # Root first, then one crumb per segment of where we are.
  def crumbs
    segments = here.split("/").reject(&:blank?)

    [["All files", ""]] + segments.each_with_index.map do |segment, index|
      [segment, segments.first(index + 1).join("/")]
    end
  end

  def listing
    div(class: "rounded border border-line bg-void/40 divide-y divide-line") do
      here_row if here.present?
      directories.each { |entry| row(entry) }
      no_subfolders if directories.empty?
    end
  end

  # Ticking where you already are, so a folder you browsed into can be picked
  # without going back up a level to find it. Not offered at the root: a folder
  # is named by its path, and the root's path is the empty string.
  def here_row
    row_shell { tick(here, here) }
  end

  # Indented under the row above, when there is one, so the listing reads as a
  # folder and its contents rather than as a row of peers. At the root there is
  # no such row — "All files" is a breadcrumb, not a line — so nothing is nested
  # under nothing.
  def row(entry)
    row_shell(indent: here.present?) do
      tick(entry.path, entry.name)
      browse_to(entry.path, "open →", css: "shrink-0 text-xs text-muted hover:text-accent transition-colors")
    end
  end

  # The checkbox and its name are one label; the browse button is pointedly
  # outside it, or clicking "open" would toggle the tick on the way past.
  #
  # Both padding classes are written out rather than built, so Tailwind's
  # scanner can see them — an interpolated class name silently does not exist.
  def row_shell(indent: false, &)
    padding = indent ? "pl-10 pr-4" : "px-4"

    div(class: "flex items-center justify-between gap-3 #{padding} py-2.5 hover:bg-ink/60 transition-colors", &)
  end

  def tick(path, label_text)
    label(class: "flex min-w-0 cursor-pointer items-center gap-3") do
      input(
        type: "checkbox",
        name: "source[folders][]",
        value: path,
        checked: picked.include?(path),
        class: "h-3.5 w-3.5 shrink-0 accent-accent"
      )
      span(class: "min-w-0 truncate text-sm text-fg") { label_text }
    end
  end

  # Every control in the picker is one of these: a GET submit carrying where to
  # look next, with the rest of the form riding along in the query string.
  def browse_to(path, label_text, css:)
    button(
      type: "submit",
      formmethod: "get",
      formaction: browse_action,
      name: "browse",
      value: path.to_s,
      class: css
    ) { label_text }
  end

  # Back to the page we are on, so browsing from the edit form stays on the edit
  # form rather than starting a new source.
  def browse_action
    @source.persisted? ? edit_source_path(@source) : new_source_path(type: @source.class.name)
  end

  def no_server
    note do
      p(class: "text-sm text-fg") { "Pick a server first." }
      p(class: "mt-1 text-xs text-faint") { "The folders come from the server, so there is nothing to list yet." }
    end
  end

  def catalogue_error
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-3 py-2.5") do
      p(class: "text-sm text-red-300") { "Couldn't read #{@source.endpoint&.name}." }
      p(class: "mt-1 font-mono text-xs text-red-300/70") { @catalogue.error }
      p(class: "mt-1.5 text-xs text-faint") { "Check the endpoint's address, username and app password, then Browse again." }
    end
  end

  def no_subfolders
    p(class: "px-4 py-3 text-xs text-faint") do
      here.present? ? "No subfolders in here." : "No folders on this server."
    end
  end

  def here = @catalogue&.at.to_s
  def directories = @catalogue&.directories || []
  def picked = @picked ||= @source.selected_folders
end
