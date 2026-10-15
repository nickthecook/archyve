module Nextcloud
  # The WebDAV half of Nextcloud, which is the only half that can list files —
  # there is no JSON API for it. Lives here rather than on Sources::Nextcloud so
  # the XML parsing can be tested without a Source.
  #
  # Paths throughout are relative to the endpoint's DAV root and carry no leading
  # slash, the same shape as Source::Item#external_id.
  class Dav
    # Exactly the properties the source uses. `allprop` would also return
    # Nextcloud's share, comment and tag properties on every entry in every
    # listing, which is a lot of XML to parse and discard.
    PROPFIND_BODY = <<~XML.freeze
      <?xml version="1.0" encoding="utf-8"?>
      <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
        <d:prop>
          <d:resourcetype/>
          <d:getcontentlength/>
          <d:getcontenttype/>
          <d:getetag/>
          <d:getlastmodified/>
          <oc:fileid/>
        </d:prop>
      </d:propfind>
    XML

    NAMESPACES = { "d" => "DAV:", "oc" => "http://owncloud.org/ns" }.freeze

    Entry = Data.define(:path, :name, :directory, :size, :etag, :content_type, :fileid, :modified_at) do
      def directory? = directory
    end

    def initialize(endpoint, timeout: Endpoint::DEFAULT_TIMEOUT)
      @endpoint = endpoint
      @timeout = timeout
    end

    # One directory's children. Not recursive: Nextcloud refuses
    # `Depth: infinity`, so walking a tree is one of these per directory.
    def list(path = "")
      entries(propfind(path, depth: 1))
    end

    # True if the path is there. Used as the endpoint's access check, where the
    # question is whether these credentials reach this user's files at all.
    def exist?(path = "")
      propfind(path, depth: 0)
      true
    end

    def read(path)
      client.get(url_for(path)).body
    end

    private

    attr_reader :endpoint, :timeout

    def propfind(path, depth:)
      client.run_request(:propfind, url_for(path), PROPFIND_BODY, {
        "Depth" => depth.to_s,
        "Content-Type" => "application/xml; charset=utf-8"
      })
    end

    # The first response element is the resource we asked about, not a child, and
    # a Depth-1 listing of a directory would otherwise report the directory as
    # being inside itself.
    def entries(response)
      document = Nokogiri::XML(response.body)

      document.xpath("//d:response", NAMESPACES).drop(1).filter_map { |element| entry_for(element) }
    end

    def entry_for(element)
      path = path_of(element)
      return if path.blank?

      Entry.new(
        path: path,
        name: File.basename(path),
        directory: element.at_xpath(".//d:resourcetype/d:collection", NAMESPACES).present?,
        size: prop(element, "d:getcontentlength")&.to_i,
        etag: prop(element, "d:getetag")&.delete('"'),
        content_type: prop(element, "d:getcontenttype").presence,
        fileid: prop(element, "oc:fileid").presence,
        modified_at: prop(element, "d:getlastmodified").presence
      )
    end

    # A property Nextcloud couldn't supply comes back in a second `propstat` with
    # a 404 status and an empty element — `getcontenttype` on a directory, for
    # one. Reading the text either way is right: absent and empty mean the same
    # thing to every caller.
    def prop(element, name)
      element.at_xpath(".//#{name}", NAMESPACES)&.text
    end

    # `d:href` is percent-encoded and absolute from the *server* root — which on
    # a subpath install includes the path the base URL carries — so it has to be
    # unescaped and have that whole prefix taken off before it means anything to
    # a caller thinking in paths relative to the DAV root.
    def path_of(element)
      href = element.at_xpath("./d:href", NAMESPACES)&.text
      return if href.blank?

      absolute = URI::DEFAULT_PARSER.unescape(URI.parse(href).path)
      prefix = endpoint.dav_href_prefix
      return unless absolute.start_with?(prefix)

      absolute.delete_prefix(prefix).delete_prefix("/").delete_suffix("/")
    end

    # Escaped per segment: a `/` separates, and only the rest is data. Escaping
    # the whole path would turn one directory into a file with slashes in its
    # name. Stays relative, so Faraday keeps the base URL's own path.
    def url_for(path)
      segments = path.to_s.split("/").reject(&:blank?).map { |segment| ERB::Util.url_encode(segment) }

      [endpoint.dav_root, *segments].join("/")
    end

    def client
      @client ||= endpoint.client(timeout: timeout)
    end
  end
end
