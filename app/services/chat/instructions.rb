# frozen_string_literal: true

module Chat
  # The system prompt. Three jobs, in order of how badly they go wrong when
  # they're missing.
  #
  # **Name the scope.** A model that doesn't know what it can reach will report
  # that the archive lacks something when the truth is the user narrowed the
  # chat to one document. It says "I couldn't find it" instead of "that's
  # outside what this chat is drawing on", and the user believes it.
  #
  # **Cite by handle.** The model is given "1", "2" and nothing else. Archyve
  # resolves those to links, so a handle it invents resolves to nothing and a
  # URL it writes is worthless. Saying so is cheaper than filtering it out.
  #
  # **Don't fill the gaps from memory.** A model that has been told the archive
  # is the authority will still happily answer a question the archive didn't
  # cover, unless it is told not to. The tool results repeat this on the paths
  # where it matters most, because instructions at the top of a long
  # conversation carry less weight than the sentence it just read.
  class Instructions
    def self.for(conversation) = new(conversation).to_s

    def initialize(conversation)
      @conversation = conversation
    end

    def to_s
      <<~TEXT.strip
        You are Archyve, answering questions from a private document archive.

        This conversation is drawing on: #{@conversation.scope_label}. That is fixed
        for the whole conversation and neither you nor the user can change it here.

        You cannot see any of these documents directly. The only way to read them is
        search_archive, so call it whenever an answer might depend on what they say.
        Send two to four differently-worded queries in one call rather than one query
        at a time — documents rarely use the same words a question does. Not every
        message needs a search: a greeting or a question about the conversation
        itself does not.

        Cite what you use. Each result comes with a handle, and you cite it by writing
        the handle in square brackets — [1], or [2][3] where two sources support the
        same point. Only ever cite a handle from the search results you were actually
        given; never invent one, never write a URL, and never cite from memory.

        If a search finds nothing, say so and say what was searched — do not fall back
        on general knowledge. If a search cannot run at all, say the archive could not
        be searched and stop there; a plausible answer from your own training is worse
        than no answer, because the person asking has no way to tell the difference.
      TEXT
    end
  end
end
