# frozen_string_literal: true

# The inside of an upload form: pick a file, say whether to OCR it, send it.
#
# Shared because there are two upload forms — the standalone one on the
# documents index and the one folded into a collection — and they differ only
# in their surroundings, not in what they ask for. They were already duplicating
# the file input; adding a second control to both is what made that worth
# fixing rather than repeating.
#
# The enclosing <form> stays with each caller: one is a bordered card, the other
# sits inside a disclosure and carries a hidden collection_slug.
class Views::Documents::UploadFields < Components::Base
  # `min-w-0 flex-1` rather than `w-full`: a full-width flex item takes the whole
  # line to itself and wraps the submit button onto the next one.
  FILE_INPUT = "block min-w-0 flex-1 text-sm text-muted file:mr-4 file:rounded file:border-0 " \
               "file:bg-accent file:px-4 file:py-2 file:text-sm file:font-medium file:text-void " \
               "hover:file:bg-accent-dim file:cursor-pointer".freeze

  SUBMIT = "shrink-0 rounded bg-accent px-4 py-2 text-sm font-medium text-void " \
           "hover:bg-accent-dim transition-colors".freeze

  DROPZONE = "mt-4 cursor-pointer rounded-lg border-2 border-dashed px-4 py-8 text-center " \
             "text-sm transition-colors".freeze

  DROPZONE_IDLE = "border-line text-faint".freeze
  DROPZONE_ACTIVE = "border-accent text-accent".freeze

  def view_template
    div(
      data: {
        controller: "file-drop",
        file_drop_idle_class: DROPZONE_IDLE,
        file_drop_active_class: DROPZONE_ACTIVE
      }
    ) do
      div(class: "flex w-full flex-wrap items-center gap-4") do
        input(type: "file", name: "file", required: true, class: FILE_INPUT,
          data: { file_drop_target: "input" })
        button(type: "submit", class: SUBMIT) { "Upload" }
      end
      dropzone
      ocr_choice
    end
  end

  private

  # A second way to reach the same input, not a second way to upload: the drop
  # hands the file to the file input above, so the filename it shows and the
  # form it submits with are the ones that were already there.
  def dropzone
    div(
      class: "#{DROPZONE} #{DROPZONE_IDLE} hover:border-line-2 hover:text-muted",
      data: {
        file_drop_target: "zone",
        action: "dragenter->file-drop#activate dragover->file-drop#activate " \
                "dragleave->file-drop#deactivate drop->file-drop#accept click->file-drop#browse"
      }
    ) { "Drop a file here, or click to browse" }
  end

  # Asked per upload rather than set once, because the right answer is a
  # property of the file: a scan needs OCR and a text-layer PDF is only made
  # slower and hungrier by it. Defaulted on, matching docling, so the
  # unconsidered upload still extracts everything.
  #
  # The hidden field ahead of the box is what makes "off" submittable at all —
  # an unchecked checkbox sends nothing, which would read as "they didn't say"
  # rather than "they said no".
  def ocr_choice
    input(type: "hidden", name: "ocr", value: "0")

    label(class: "mt-3 flex cursor-pointer items-start gap-2.5") do
      input(type: "checkbox", name: "ocr", value: "1", checked: true, class: "mt-0.5 h-3.5 w-3.5 accent-accent")
      span do
        span(class: "text-sm text-muted") { "Read text from images (OCR)" }
        span(class: "block text-xs text-faint") do
          "Needed for scans and photographed pages. Slow and memory-hungry — turn it off for files that already have selectable text."
        end
      end
    end
  end
end
