require "csv"

module Reviews
  # The Review list as a spreadsheet, filtered the same way. Like the page, it
  # never says who asked.
  class Export
    HEADERS = ["Asked at", "Chat", "Scope", "Model", "Question", "Answer", "Error", "Rating", "Comment", "Documents"].freeze
    RATINGS = { "up" => "good", "down" => "bad" }.freeze

    # Spreadsheets run a cell starting with one of these as a formula, and
    # questions and answers are text nobody here wrote.
    FORMULA = /\A[=+\-@\t\r]/

    def initialize(answers)
      @answers = answers.includes(segments: :hits)
      @scopes = {}
    end

    def to_csv
      CSV.generate do |csv|
        csv << HEADERS
        @answers.find_in_batches(order: :desc) do |batch|
          Listing.turns(batch).each { csv << row(it).map { defused(it) } }
        end
      end
    end

    private

    def row(turn)
      answer = turn.answer
      [
        answer.created_at.iso8601, answer.conversation_id, scope_of(answer.conversation),
        answer.inference_model&.label, turn.question&.text, answer.prose, answer.error,
        RATINGS[answer.feedback&.rating], answer.feedback&.comment, documents(answer)
      ]
    end

    def scope_of(conversation) = @scopes[conversation.id] ||= conversation.scope_label

    def documents(answer)
      answer.segments.flat_map(&:hits).map(&:document_title).uniq.join("; ")
    end

    def defused(value) = value.is_a?(String) && value.match?(FORMULA) ? "'#{value}" : value
  end
end
