class AddFailureFactsToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :failure_stage, :string
    add_column :documents, :failure_kind, :string
    add_column :documents, :failure_detail, :text

    # Partial: almost every row is null, and the question this answers —
    # "what's failing, and is it the same thing every time?" — only ever asks
    # about the ones that aren't.
    add_index :documents, :failure_kind, where: "failure_kind IS NOT NULL"
  end
end
