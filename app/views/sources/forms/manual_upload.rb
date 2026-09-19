# frozen_string_literal: true

# Manual upload isn't created from a form — there is one per person, made on
# their first upload — but it can still be renamed, so it needs one to edit.
class Views::Sources::Forms::ManualUpload < Views::Sources::Form
  def self.edit_blurb = "Documents arrive here by being uploaded. There is nothing to scan and nothing to point at."

  private

  def type_fields = nil
end
