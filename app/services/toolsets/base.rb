# frozen_string_literal: true

module Toolsets
  # A toolset is built per conversation and gives its tools whatever context
  # they need, so tools outside the archive aren't tied to its corpus and handles.
  class Base
    def self.key = name.demodulize.underscore

    def initialize(conversation)
      @conversation = conversation
    end

    def instructions = raise(NotImplementedError, "#{self.class} must say what the model needs to know")

    def tools(observer:) = raise(NotImplementedError, "#{self.class} must build its tools")
  end
end
