# Whether this particular document should be OCR'd, when the answer was made
# deliberately rather than inherited. Nullable, and null is not "no" — it means
# "whatever the source says", which is what every document fed by a connector
# wants: change the connector's setting, reprocess, and its documents follow.
#
# A manual upload stores an explicit answer because the person uploading was
# asked, and their answer has to survive a reprocess months later.
class AddOcrToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :ocr, :boolean
  end
end
