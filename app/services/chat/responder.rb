# frozen_string_literal: true

module Chat
  # Answers one user message: replays the conversation, hands the model its
  # tools, and streams what comes back into a Turn.
  #
  # ## Nothing here raises at the user
  #
  # Every failure ends as a recorded error on the turn. A chat that 500s loses
  # the question along with the answer, and the person asking has no idea
  # whether their archive is broken or their model is.
  class Responder
    # Enough for a provider to say what it wants — vLLM's tool-call refusal
    # names two flags — without a wall of JSON landing in the transcript.
    PROVIDER_MESSAGE_LIMIT = 300

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

      return turn.fail!(agent_refused_message) unless @conversation.agent.usable_by?(@conversation.user)
      return turn.fail!(no_model_message) if model.nil?
      return turn.fail!(no_tools_message(model)) unless model.supports_tools?

      respond(model, turn)
    end

    private

    def respond(model, turn)
      # Files any recorded API call under this turn, so a transcript that went
      # wrong can be read next to the calls that produced it. Nothing when
      # recording is off — see ApiCall.
      Current.api_call_traceable = @answer

      chat = build_chat(model, turn)
      assumed = assumed_token_count(model)
      chat.ask(@user_message.text) do |chunk|
        # One count for both channels, because a chunk carries text on one of
        # them: whichever it is, the other call returns before it ticks. Nil
        # where neither the server nor the assumption can say — see Chat::Pace.
        tokens = chunk.streamed_token_count || assumed
        # Two channels, one stream. Providers that reason put the analysis in
        # `thinking` and only the reply in `content`; the turn keeps them apart
        # so the transcript can too. A provider that doesn't reason simply never
        # sets it.
        turn.append_thinking(chunk.thinking&.text, tokens:)
        turn.append(chunk.content, tokens:)
        # How much of the window this conversation now fills, as the server
        # counted it. Arrives on its own chunk at the end of each round, which
        # carries no text — so it is noted here rather than alongside a delta.
        turn.note_context(chunk.input_tokens)
      end
      # Once per turn, not once per chunk: `ask` is a single call, however much
      # it streams back through the block above.
      model.inference_server.mark_reachable!
      turn.finish
    rescue StandardError => e
      Rails.logger.error("chat turn failed for conversation #{@conversation.id}: #{e.class}: #{e.message}")
      note_unreachable(model, e)
      turn.fail!(failure_message(model, e))
    end

    # What a delta is worth where the server didn't say — one token on Ollama,
    # and nothing anywhere else. Resolved once per turn: it is a fact about the
    # server, and asking per chunk would ask thousands of times.
    def assumed_token_count(model)
      1 if model.inference_server.one_token_per_delta?
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
      params = model.inference_server.stream_params
      chat.with_params(**params) if params.any?
      @conversation.toolsets.flat_map { it.tools(observer: turn) }.each { chat.with_tool(it) }
      replay(chat)
      chat
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

    # Checked per turn, not when the chat started: an agent can gain a toolset
    # with a higher floor after the conversation began.
    def agent_refused_message
      "You no longer have access to #{@conversation.agent.name}, so it can't answer here."
    end

    def no_tools_message(model)
      "#{model.label} can't call tools, so it can't search your archive. Pick a tool-capable model."
    end

    # A server that answered with a refusal is not a server that is down, and
    # saying "check that it's running" sends someone to look at the one thing
    # that is fine. A vLLM host refusing tool calls names the two flags it
    # wants started with; that sentence belongs on the turn, not only the log.
    #
    # Provider messages come through because they are written for whoever is
    # wiring the thing up. Ours don't: this rescue is deliberately broad enough
    # to catch Archyve's own bugs, and a NoMethodError means nothing to the
    # person who asked a question.
    def failure_message(model, error)
      return unreachable_message(model) if InferenceServer.unreachable_error?(error)
      return "Something went wrong answering that. The details are in the log." unless error.is_a?(RubyLLM::Error)

      name = model&.inference_server&.name || "The chat model"
      "#{name} couldn't answer: #{error.message.truncate(PROVIDER_MESSAGE_LIMIT)}"
    end

    def unreachable_message(model)
      "Couldn't reach #{model&.inference_server&.name || 'the chat model'}. Check that it's running."
    end
  end
end
