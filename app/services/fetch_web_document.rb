class FetchWebDocument
  def initialize(document)
    @document = document
  end

  def execute
  rescue StandardError => e
    document.update(state: :errored, error_message: e.to_s)
  end

  private

  def fetch_file_content
    f = Tempfile.create(['web-', '.html'])
    f.puts HTTParty.get(params[:link])
    f.rewind
    document.file = f
    document.filename = File.basename(f.path)
  end
end
