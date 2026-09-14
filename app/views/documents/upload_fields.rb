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
  FILE_INPUT = "block w-full text-sm text-muted file:mr-4 file:rounded file:border-0 " \
               "file:bg-accent file:px-4 file:py-2 file:text-sm file:font-medium file:text-void " \
               "hover:file:bg-accent-dim file:cursor-pointer".freeze

  SUBMIT = "shrink-0 rounded bg-accent px-4 py-2 text-sm font-medium text-void " \
           "hover:bg-accent-dim transition-colors".freeze

  def view_template
    div(class: "flex w-full items-center gap-4") do
      input(type: "file", name: "file", required: true, class: FILE_INPUT)
      button(type: "submit", class: SUBMIT) { "Upload" }
    end
    ocr_choice
  end

  private

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
