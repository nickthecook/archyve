module Reviews
  # Every finished answer, opening on the ones somebody said something about.
  class Listing < FilteredListing
    Turn = Data.define(:question, :answer)

    # Fewer than a table's worth: each one is a card several lines tall.
    PER_PAGE = 20

    FEEDBACK = {
      "given" => ->(rows) { rows.where(id: Feedback.select(:message_id)) },
      "up" => ->(rows) { rows.where(id: Feedback.up.select(:message_id)) },
      "down" => ->(rows) { rows.where(id: Feedback.down.select(:message_id)) },
      "commented" => ->(rows) { rows.where(id: Feedback.commented.select(:message_id)) },
      "none" => ->(rows) { rows.where.not(id: Feedback.select(:message_id)) }
    }.freeze

    FILTERS = [
      Filter.new(param: "feedback", label: "Feedback", default: "given", blank: "All answers",
        options: -> {
          [["given", "With feedback"], ["up", "Rated good"], ["down", "Rated bad"],
            ["commented", "With a comment"], ["none", "Without feedback"]]
        },
        narrow: ->(rows, value) { FEEDBACK.fetch(value).call(rows) }),
      Filter.new(param: "outcome", label: "Outcome", options: -> { [["answered", "Answered"], ["failed", "Failed"]] },
        narrow: ->(rows, value) { value == "failed" ? rows.where.not(error: nil) : rows.where(error: nil) })
    ].freeze

    # Each answer with the question it answered, which Chat::Ask always writes
    # one position before it.
    def self.turns(answers)
      questions = Message.user.includes(:segments)
        .where(conversation_id: answers.map(&:conversation_id), position: answers.map { it.position - 1 })
        .index_by { [it.conversation_id, it.position] }

      answers.map { Turn.new(question: questions[[it.conversation_id, it.position - 1]], answer: it) }
    end

    private

    def per_page = PER_PAGE

    def base
      Message.assistant.where.not(completed_at: nil)
        .includes(:feedback, :inference_model, :segments, :conversation)
    end
  end
end
