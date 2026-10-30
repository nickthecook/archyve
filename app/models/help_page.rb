# frozen_string_literal: true

# A markdown file under help/, addressed by its path without the extension:
# help/sources/folder.md is /help/sources/folder, and a directory's index.md is
# the directory. Links and images are written relative to the file, the way
# they read in the repo, and rewritten to absolute /help URLs on render.
class HelpPage
  # No dots, so no `..`; no leading underscore, so _sidebar.md isn't a page.
  SEGMENT = /\A[a-z0-9][a-z0-9_-]*\z/i
  IMAGE = /\A[a-z0-9][a-z0-9_-]*\.(png|jpe?g|gif|webp)\z/i
  SIDEBAR = "_sidebar.md"

  attr_reader :relative

  def self.root = Rails.root.join("help")

  def self.find(path)
    segments = path.to_s.split("/")
    return unless segments.all? { it.match?(SEGMENT) }

    candidates = segments.empty? ? ["index.md"] : ["#{segments.join('/')}.md", [*segments, "index.md"].join("/")]
    relative = candidates.find { root.join(it).file? }
    new(relative) if relative
  end

  def self.image(path)
    *directories, name = path.to_s.split("/")
    return unless name&.match?(IMAGE) && directories.all? { it.match?(SEGMENT) }

    file = root.join(path)
    file if file.file?
  end

  def self.sidebar
    new(SIDEBAR) if root.join(SIDEBAR).file?
  end

  def self.url_for(relative)
    path = relative.delete_suffix(".md").sub(%r{(\A|/)index\z}, "")
    Rails.application.routes.url_helpers.help_path(path: path.presence)
  end

  def initialize(relative)
    @relative = relative
  end

  def url = self.class.url_for(relative)

  def title
    fragment.at_css("h1")&.text.presence || File.basename(relative, ".md").humanize
  end

  # `current` marks the link to that URL, for a page that lists others.
  def html(current: nil)
    fragment.tap do |doc|
      doc.css("a[href]").select { it["href"] == current }.each { it["aria-current"] = "page" }
    end.to_html
  end

  private

  def fragment
    Markdown.fragment(self.class.root.join(relative).read, authored: true).tap do |doc|
      doc.css("a[href]").each { it["href"] = resolve(it["href"]) }
      doc.css("img[src]").each { it["src"] = resolve(it["src"]) }
    end
  end

  def resolve(reference)
    return reference if reference.match?(%r{\A([a-z][a-z0-9+.-]*:|/|#)}i)

    target, anchor = reference.split("#", 2)
    resolved = Pathname(relative).dirname.join(target).cleanpath.to_s
    [self.class.url_for(resolved), anchor].compact.join("#")
  end
end
