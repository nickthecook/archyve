class FetchWebDocument
  def initialize(document)
    @document = document
  end

  def execute
    reset_document unless @document.created?

    @document.fetching!

    fetch_file_content
    set_document_attachment
    tempfile.close

    @document.fetched!
  end

  private

  def reset_document
    ResetDocument.new(@document).execute
  end

  def set_document_attachment
    @document.update!(filename: File.basename(tempfile.path))

    @document.file.attach(io: tempfile, filename: @document.filename)
  end

  def fetch_file_content
    content = HTTParty.get(@document.link)
    tempfile.write(content)
    tempfile.rewind
  end

  def tempfile
    @tempfile ||= Tempfile.create(['web-', '.html'])
  end
end
