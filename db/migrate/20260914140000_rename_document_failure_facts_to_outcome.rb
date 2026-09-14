# The columns turned out to be narrower than the thing they hold. Docling can
# convert a document and still report that a page didn't parse — a real result
# with a shortfall in it, not a failure — and a row called `failure_kind` has
# nowhere honest to put that. Renamed rather than joined by a second set of
# columns, because there is only ever one verdict on a document and two places
# to look for it is how they drift.
#
# rename_column carries the data and the partial index across, so nothing
# already recorded in production is lost.
class RenameDocumentFailureFactsToOutcome < ActiveRecord::Migration[8.1]
  def change
    rename_column :documents, :failure_stage, :outcome_stage
    rename_column :documents, :failure_kind, :outcome_kind
    rename_column :documents, :failure_detail, :outcome_detail
  end
end
