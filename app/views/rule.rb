# frozen_string_literal: true

# The zone break: ways out above, the page's own content below. One per page —
# see docs/design.md.
#
# `line-2` rather than `line` because `line` is what every card and input on the
# page outlines in, and a boundary drawn in the most common ink in view doesn't
# read as a boundary. The margins collapse against the preceding block, so a
# caller sets no spacing of its own.
class Views::Rule < Components::Base
  def view_template
    hr(class: "my-10 border-line-2")
  end
end
