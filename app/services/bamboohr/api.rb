module Bamboohr
  # The parts of the BambooHR API a file source reads: company file categories
  # with their files, and a file's bytes.
  class Api
    Category = Data.define(:id, :name, :files)
    StoredFile = Data.define(:id, :name, :original_file_name, :size, :created_at)

    def initialize(endpoint, timeout:)
      @endpoint = endpoint
      @timeout = timeout
    end

    def categories = categories_in(get("api/v1/files/view"))

    def read(file_id) = client.get("api/v1/files/#{file_id}").body

    private

    attr_reader :endpoint, :timeout

    def client
      @client ||= endpoint.client(timeout:)
    end

    def get(path, params = {})
      JSON.parse(client.get(path, params).body)
    end

    def categories_in(body)
      body.fetch("categories", []).map do |category|
        files = Array(category["files"]).map do |file|
          StoredFile.new(
            id: file["id"].to_s,
            name: file["name"].presence || file["originalFileName"],
            original_file_name: file["originalFileName"].to_s,
            size: file["size"].to_i,
            created_at: file["dateCreated"].to_s
          )
        end

        Category.new(id: category["id"].to_i, name: category["name"], files:)
      end
    end
  end
end
