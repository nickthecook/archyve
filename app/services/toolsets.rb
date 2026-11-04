# frozen_string_literal: true

# Toolsets are code, not rows: tools are Ruby classes, so a table would only
# mirror this list. See issue #92.
module Toolsets
  def self.all = [Archive]

  def self.keys = all.map(&:key)

  def self.fetch(key) = all.find { it.key == key } || raise(KeyError, "no toolset named #{key.inspect}")
end
