module Sharepoint
  # The parts of Microsoft Graph a SharePoint source reads: a site's document
  # libraries, one folder's children, and a file's bytes. Paths are relative to
  # a library's root, "/"-joined, without slashes at either end.
  class Graph
    PAGE_SIZE = 200
    FIELDS = "id,name,folder,file,size,cTag,eTag,webUrl,lastModifiedDateTime".freeze

    # Created by Microsoft 365 retention, and holding old versions and deleted
    # files — ingesting it would resurrect what people removed.
    PRESERVATION_HOLD = "/PreservationHoldLibrary".freeze

    # SharePoint refuses a download URL whose query Faraday has sorted and
    # re-escaped, so the one Graph hands out is sent exactly as written.
    module VerbatimQuery
      KEY = "query".freeze

      def self.decode(query) = query.nil? ? {} : { KEY => query }
      def self.encode(params) = params[KEY]
    end

    Drive = Data.define(:id, :name)
    Entry = Data.define(:id, :name, :path, :directory, :size, :version, :web_url, :modified_at) do
      def directory? = directory
    end

    def initialize(endpoint, timeout:)
      @endpoint = endpoint
      @timeout = timeout
    end

    def drives
      fetch_all(endpoint.site_path("drives"), "$select" => "id,name,webUrl")
        .reject { |drive| drive["webUrl"].to_s.end_with?(PRESERVATION_HOLD) }
        .map { |drive| Drive.new(id: drive["id"], name: drive["name"]) }
    end

    def list(drive_id, path = "")
      fetch_all(children_path(drive_id, path), "$select" => FIELDS, "$top" => PAGE_SIZE)
        .map { |item| entry(item, path) }
    end

    # Graph's own /content answers with a redirect to a pre-authenticated URL;
    # asking for the URL and fetching it without our token comes to the same.
    def read(drive_id, item_id)
      url = endpoint.graph_get("drives/#{drive_id}/items/#{item_id}", {}, timeout:)
        .fetch("@microsoft.graph.downloadUrl")
      connection = Http.connection(nil, timeout:)
      connection.options.params_encoder = VerbatimQuery
      connection.get(url).body
    end

    private

    attr_reader :endpoint, :timeout

    # A nextLink is absolute and carries the query, which Faraday follows as-is.
    def fetch_all(path, params)
      items = []

      while path
        body = endpoint.graph_get(path, params, timeout:)
        items.concat(body.fetch("value", []))
        path = body["@odata.nextLink"]
        params = {}
      end

      items
    end

    def children_path(drive_id, path)
      return "drives/#{drive_id}/root/children" if path.blank?

      encoded = path.split("/").map { |segment| ERB::Util.url_encode(segment) }.join("/")
      "drives/#{drive_id}/root:/#{encoded}:/children"
    end

    # cTag moves only when the content does, so a rename isn't a re-ingest.
    def entry(item, parent)
      Entry.new(
        id: item["id"],
        name: item["name"],
        path: [parent.presence, item["name"]].compact.join("/"),
        directory: item.key?("folder"),
        size: item["size"],
        version: item["cTag"].presence || item["eTag"],
        web_url: item["webUrl"],
        modified_at: item["lastModifiedDateTime"]
      )
    end
  end
end
