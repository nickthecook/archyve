class FetchWebDocument
  def initialize(document)
    @document = document
    @uri = URI(document.link)
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
    content = HTTParty.get(@uri)
    tempfile.write(content)
    tempfile.rewind
  end

  def tempfile
    @tempfile ||= Tempfile.create(['web-', file_extension], binmode: true)
  end

  def file_extension
    Pathname.new(@uri.path).extname
  end
end
