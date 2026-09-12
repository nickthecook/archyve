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
      turn = Turn.new(@conversation)
      model = chat_model

      return turn.fail!(no_model_message) if model.nil?
      return turn.fail!(no_tools_message(model)) unless model.supports_tools?

      respond(model, turn)
    end

    private

    def respond(model, turn)
      chat = build_chat(model, turn)
      chat.ask(@user_message.text) { |chunk| turn.append(chunk.content) }
      turn.finish
    rescue StandardError => e
      Rails.logger.error("chat turn failed for conversation #{@conversation.id}: #{e.class}: #{e.message}")
      turn.fail!(unreachable_message(model))
    end

    def build_chat(model, turn)
      chat = model.inference_server.llm_context.chat(
        model: model.name,
        provider: model.inference_server.ruby_llm_provider,
        assume_model_exists: true
      )
      chat.with_instructions(Instructions.for(@conversation))
      # `calls:` is RubyLLM's own ceiling on tool rounds in a single turn — the
      # guard against a confused model searching in circles. It stops calling
      # the tool and answers with what it has.
      chat.with_tool(tool(turn), calls: Setting.chat_max_tool_rounds)
      replay(chat)
      chat
    end

    def tool(turn)
      Retrieval::Tool.new(
        user: @conversation.user,
        scope: @conversation.retrieval_scope,
        scope_label: @conversation.scope_label,
        limit: Setting.chat_result_limit,
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
