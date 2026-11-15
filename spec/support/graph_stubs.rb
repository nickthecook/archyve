# Microsoft Graph behind an Endpoints::Sharepoint, stubbed at Http so the token
# exchange and the request paths are exercised rather than bypassed.
module GraphStubs
  GRAPH = "/v1.0".freeze

  def stub_graph(stubs)
    allow(Http).to receive(:connection) do |url, **|
      Faraday.new(url: url) do |f|
        f.request :url_encoded
        f.adapter(:test, stubs)
      end
    end

    stubs.post("/example.onmicrosoft.com/oauth2/v2.0/token") do
      [200, {}, { access_token: "graph-token", expires_in: 3599 }.to_json]
    end
  end

  def stub_graph_get(stubs, path, body = nil, status: 200, **fields)
    stubs.get("#{GRAPH}/#{path}") { [status, {}, (body || fields).to_json] }
  end

  def graph_folder(name) = { id: "folder-#{name}", name: name, folder: { childCount: 1 } }

  def graph_file(name, id: "file-#{name}", size: 1024, ctag: "ctag-#{name}")
    { id:, name:, size:, cTag: ctag, file: {}, webUrl: "https://example.sharepoint.com/sites/Team/#{name}",
      lastModifiedDateTime: "2026-11-01T10:00:00Z" }
  end
end

RSpec.configure { |config| config.include GraphStubs }
