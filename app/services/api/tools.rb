# frozen_string_literal: true

module Api
  # The tools /api/tools exposes. See Api::Tools::Base.
  module Tools
    def self.all = [Search, ListCollections, ListDocuments, Read]

    def self.find(name) = all.find { it.tool_name == name }
  end
end
