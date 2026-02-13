class Fact < Document
  def parser
    Parsers::Fact.new(self)
  end
end
