class ResetDocument
  def initialize(document)
    @document = document
  end

  def execute
    Rails.logger.warn("RESETTING DOCUMENT #{@document.id}: is in state #{@document.state}...")

    Helpers::DocumentResetHelper.new(@document).execute
    @document.update!(state: :created, error_message: nil)
  end
end
