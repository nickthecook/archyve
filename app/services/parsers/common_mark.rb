module Parsers
  # Markdown text chunker that uses recursive text splitter, with a separator
  # specification that uses markdown semantics and considers HTML tables
  class CommonMark < Text
    def _chunking_separators
      [
        # markdown-specific separators
        "\n# ", # h1
        "\n## ", # h2
        "\n### ", # h3
        "\n#### ", # h4
        "\n##### ", # h5
        "\n###### ", # h6
        "```\n\n", # code block
        "\n\n***\n\n", # horizontal rule
        "\n\n---\n\n", # horizontal rule
        "\n\n___\n\n", # horizontal rule
        "\n\n", # new line

        # html table content-related separators
        "\n<table",
        "<tr",  # may have attributes
        "<td>",
        "<ul>", # html lists (usually within tables)
        "<ol>",
        "<li>",

        # plain text
        "\n", # new line
        " ", # space
        "", # empty
      ]
    end
  end
end
