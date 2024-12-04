class DestroyDocument
  def initialize(document)
    @document = document
  end

  # Destroy the document and all it's related content / children
  def execute
    @document.deleting!
    Helpers::DocumentResetHelper.new(@document).execute
    @document.destroy!
  end
end
