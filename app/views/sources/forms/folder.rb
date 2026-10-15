# frozen_string_literal: true

class Views::Sources::Forms::Folder < Views::Sources::Form
  def self.new_heading = "Add a folder"

  def self.new_blurb
    "Archyve scans the folder on an interval and keeps the archive matching what's in it."
  end

  def self.edit_blurb
    "Changing the folder re-scans from scratch: documents that aren't under the new path are removed from the archive."
  end

  private

  def type_fields
    field("Folder", "An absolute path on the machine running Archyve. Read, never written.") do
      text_input(:path, @source.path, placeholder: "/srv/documents", mono: true)
      what_gets_scanned
    end
  end

  # Which files the scan will actually pick up. Stated up front rather than left
  # to be discovered by a file not showing up. Not editable yet — when it is,
  # this becomes the input rather than the description of a constant.
  def what_gets_scanned
    div(class: "mt-2 rounded border border-line bg-void/40 px-3 py-2.5") do
      p(class: "text-xs text-muted") { "Scanned, recursively:" }
      div(class: "mt-1.5 flex flex-wrap gap-1") do
        Source::EXTRACTABLE_EXTENSIONS.each do |extension|
          span(class: "rounded border border-line px-1.5 py-0.5 font-mono text-[0.7rem] text-faint") { extension }
        end
      end
      p(class: "mt-2 text-xs text-faint") { skipped_summary }
    end
  end

  def skipped_summary
    limit = ActiveSupport::NumberHelper.number_to_human_size(Source.max_file_size)
    "Other extensions are ignored. Hidden files, symlinks, empty files, and files over #{limit} are skipped."
  end
end
