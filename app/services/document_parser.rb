class DocumentParser
  def initialize(document)
    @document = document
  end

  def pages
    reader.pages.size
  end

  def page(index)
    reader.page(index).text
  end

  def text
    @text ||= begin
      text = ""
      reader.pages.each do |page|
        text << page.text
      end

      text
    end
  end

  private

  def reader
    @reader ||= begin
      io = StringIO.new
      io.puts(@document.contents)
      
      PDF::Reader.new(io)
    end
  end
end
