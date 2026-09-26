# frozen_string_literal: true

module Chat
  # Answers one user message: replays the conversation, hands the model its
  # tools, and streams what comes back into a Turn.
  #
  # ## Why a tool-capable model is required
  #
  # There is no fallback that stuffs the user's message into a prompt as
  # context. That approach answers the wrong question: retrieval isn't only
  # *finding* passages, it's deciding whether this message calls for a search at
  # all and what to search for, and a user's message is frequently neither a
  # good query nor a request to search anything. A model that can't call tools
  # can't make either decision, so chat declines rather than degrading into
  # something that looks like it works.
  #
  # ## Nothing here raises at the user
  #
  # Every failure ends as a recorded error on the turn. A chat that 500s loses
  # the question along with the answer, and the person asking has no idea
  # whether their archive is broken or their model is.
  class Responder
    def self.call(user_message, answer) = new(user_message, answer).call

    # `answer` is the assistant turn, already opened by Chat::Ask — see the note
    # there for why it is created in the request rather than here.
    def initialize(user_message, answer)
      @user_message = user_message
      @answer = answer
      @conversation = user_message.conversation
    end

    def call
      # Read off the turn rather than resolved again here: the model that was
      # asked is the one stamped when the question was, so a turn that never
      # happens can still say which model failed it.
      model = @answer.inference_model
      turn = Turn.new(@answer)

      return turn.fail!(no_model_message) if model.nil?
      return turn.fail!(no_tools_message(model)) unless model.supports_tools?

      respond(model, turn)
    end

    private

    def respond(model, turn)
      chat = build_chat(model, turn)
      chat.ask(@user_message.text) do |chunk|
        # Two channels, one stream. Providers that reason put the analysis in
        # `thinking` and only the reply in `content`; the turn keeps them apart
        # so the transcript can too. A provider that doesn't reason simply never
        # sets it.
        turn.append_thinking(chunk.thinking&.text)
        turn.append(chunk.content)
      end
      # Once per turn, not once per chunk: `ask` is a single call, however much
      # it streams back through the block above.
      model.inference_server.mark_reachable!
      turn.finish
    rescue StandardError => e
      Rails.logger.error("chat turn failed for conversation #{@conversation.id}: #{e.class}: #{e.message}")
      note_unreachable(model, e)
      turn.fail!(unreachable_message(model))
    end

    # Only a genuine no-answer marks the server down. This rescue is deliberately
    # broad — nothing here raises at the user — so it also catches bugs in
    # Archyve, and a NoMethodError of ours has no business putting a red dot on a
    # host that is fine.
    def note_unreachable(model, error)
      model.inference_server.mark_unreachable!(error) if InferenceServer.unreachable_error?(error)
    end

    def build_chat(model, turn)
      chat = model.inference_server.llm_context.chat(
        model: model.name,
        provider: model.inference_server.ruby_llm_provider,
        assume_model_exists: true
      )
      chat.with_instructions(Instructions.for(@conversation))
      # A chat scoped to no collections gets no tools at all. Handing it ones
      # that can only return "nothing found" would have the model reporting an
      # empty archive when the truth is that nobody pointed it at one.
      tools(turn).each { chat.with_tool(it) } if @conversation.searches_archive?
      replay(chat)
      chat
    end

    # One corpus and one handle counter for the whole turn, shared by every
    # tool: the corpus so search and read can't disagree about what this
    # conversation can see, the counter so they cite into one namespace.
    #
    # The round limit is each tool's own — RubyLLM's `calls:` counts tool calls
    # within one response, not rounds within a turn, and passing a number to it
    # raises.
    def tools(turn)
      shared = {
        corpus: Retrieval::Corpus.for(@conversation),
        handles: Retrieval::Handles.new,
        observer: turn
      }
      rounds = Setting.chat_max_tool_rounds
      # Listings get their own, looser budget: they cost no embedding call, and
      # finding one's way around an archive takes more steps than answering from
      # it. See the setting for where the ceiling comes from.
      listing_rounds = Setting.chat_max_listing_rounds

      [
        Tools::Search.new(limit: Setting.chat_result_limit, max_rounds: rounds, **shared),
        Tools::Read.new(max_rounds: rounds, **shared),
        Tools::ListCollections.new(max_rounds: listing_rounds, **shared),
        Tools::ListDocuments.new(max_rounds: listing_rounds, **shared)
      ]
    end

    # Everything before this question. Past searches come back with it — see
    # Segment#for_history — so a follow-up can refer to what was found without
    # searching for it again.
    def replay(chat)
      @conversation.messages.where(position: ...@user_message.position).each do |message|
        content = message.history_content
        chat.add_message(role: message.role.to_sym, content: content) if content.present?
      end
    end

    # The model row can be nullified out from under an old conversation, and a
    # fresh install has none at all, so this is an ordinary state rather than an
    # error — but it is the user's own conversation, so they hear about it.
    def no_model_message
      "No chat model is configured. Ask an admin to add a tool-capable one under Settings › Inference."
    end

    def no_tools_message(model)
      "#{model.label} can't call tools, so it can't search your archive. Pick a tool-capable model."
    end

    def unreachable_message(model)
      "Couldn't reach #{model&.inference_server&.name || 'the chat model'}. Check that it's running."
    end
  end
end
