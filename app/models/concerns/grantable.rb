# The grant vocabulary, shared by collection and source grants so User#may_on?
# can compare either. Named for what each grant permits on its object; the
# global role is a separate ladder — see docs/architecture.md.
module Grantable
  extend ActiveSupport::Concern

  ACCESS = { accessor: 0, editor: 1, manager: 2 }.freeze

  included do
    enum :access, ACCESS, validate: true
  end

  def self.strongest(levels) = levels.max_by { ACCESS.fetch(it.to_sym) }
end
