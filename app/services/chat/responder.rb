# frozen_string_literal: true

module Chat
  # Answers one user message: replays the conversation, hands the model the
  # retrieval tool, and streams what comes back into a Turn.
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
    def self.call(user_message) = new(user_message).call

    def initialize(user_message)
      @user_message = user_message
      @conversation = user_message.conversation
    end

    def call
      # Resolved before the turn exists, so the turn is stamped with the model
      # that was asked even when the answer never happens — a failed turn that
      # can't say which model failed is a support question waiting to be asked.
      model = chat_model
      turn = Turn.new(@conversation, model: model)

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
      # A chat scoped to no collections gets no search tool at all. Handing it
      # one that can only return "nothing found" would have the model reporting
      # an empty archive when the truth is that nobody pointed it at one.
      chat.with_tool(tool(turn)) if @conversation.searches_archive?
      replay(chat)
      chat
    end

    # The round limit is the tool's own — RubyLLM's `calls:` counts tool calls
    # within one response, not rounds within a turn, and passing a number to it
    # raises.
    def tool(turn)
      Retrieval::Tool.new(
        user: @conversation.user,
        scope: @conversation.retrieval_scope,
        scope_label: @conversation.scope_label,
        limit: Setting.chat_result_limit,
        max_rounds: Setting.chat_max_tool_rounds,
        observer: turn
      )
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
    def chat_model = @conversation.inference_model || InferenceModel.default_chat

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
