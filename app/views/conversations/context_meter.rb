# frozen_string_literal: true

# How much of the model's context window this conversation is filling — the
# whole transcript, the instructions, the tool schemas and every tool result the
# model was handed.
#
# Two readings, drawn differently. A settled conversation shows what the server
# itself counted. A turn in flight shows Chat::Context's running guess, marked
# with a tilde, which the server's own figure replaces when the turn closes.
#
# A broadcast target: Chat::Turn replaces it as the turn streams and again as it
# closes. Kept helper-free — dom_id computed directly, no route
# helpers — so it can be rendered to a string outside a request, the same way
# Views::Conversations::Message is.
#
# It reads one turn, not the conversation's total. See
# Conversation#context_turn for why the turn is the thing that can be
# measured, and Chat::Turn#note_context for why rounds are not added up.
class Views::Conversations::ContextMeter < Components::Base
  # Where the fill changes colour, as a share of the window, each band naming
  # its ceiling.
  #
  # Utilisation is not an ingestion status, so this deliberately doesn't borrow
  # Views::Documents::StatusBadge's vocabulary. It climbs *through* brass rather
  # than resting there: a meter that were brass at idle would spend the page's
  # whole accent budget saying nothing was wrong. See docs/design.md.
  BANDS = [
    [0.5, "bg-emerald-600"],
    [0.8, "bg-accent"],
    [Float::INFINITY, "bg-red-400"]
  ].freeze

  def self.dom_id(conversation) = ActionView::RecordIdentifier.dom_id(conversation, :context)

  def initialize(conversation:)
    @turn = conversation.context_turn
    @dom_id = self.class.dom_id(conversation)
  end

  # The element renders even with nothing to show — a chat nobody has asked
  # anything yet, a provider that reported no usage, a model whose window nobody
  # filled in. It is what Chat::Turn replaces, and a target the page doesn't
  # have is a broadcast that lands nowhere.
  def view_template
    return div(id: @dom_id) if fraction.nil?

    div(id: @dom_id, class: "mb-2 flex justify-end") do
      div(class: "flex items-center gap-2.5", title: full_reading) do
        span(class: "text-[0.7rem] uppercase tracking-[0.12em] text-faint") { "Context" }
        track
        span(class: "font-mono text-[0.7rem] tabular-nums text-muted") { reading }
      end
    end
  end

  private

  def fraction = @turn&.context_fraction

  # Same track as the collection cards' status meter: a hollow pill the fill
  # sits in. Fixed width rather than full — it shares a line with its own
  # reading, and a bar as wide as the composer would read as a loading bar for
  # the page.
  def track
    div(
      class: "h-1.5 w-28 overflow-hidden rounded-full bg-line/50 sm:w-40",
      role: "progressbar",
      aria_valuenow: @turn.input_tokens, aria_valuemin: 0, aria_valuemax: window,
      aria_label: "Context used"
    ) do
      div(class: "h-full rounded-full #{band}", style: "width: #{percent}%")
    end
  end

  def window = @turn.inference_model.context_window

  # Clamped, because the fraction isn't: a server started with a shorter window
  # than Archyve was told reports a prompt that overflows it, and a fill wider
  # than its track escapes the rounded corners it was clipped by.
  def percent = (fraction.clamp(0, 1) * 100).round(2)

  def band = BANDS.find { |ceiling, _| fraction < ceiling }.last

  # A tilde while the turn is running: that figure is Chat::Context's guess, and
  # it is replaced by the server's own count the moment the turn closes. The
  # mark is what keeps a number that visibly jumps at the end from reading as a
  # glitch.
  def reading = "#{'~' if estimated?}#{compact(@turn.input_tokens)} / #{compact(window)}"

  def estimated? = @turn.in_progress?

  def full_reading
    return "about #{exact(@turn.input_tokens)} of #{exact(window)} tokens so far — #{@turn.inference_model.label} " \
           "reports the real figure when the turn ends" if estimated?

    "#{exact(@turn.input_tokens)} of #{exact(window)} tokens, " \
      "as #{@turn.inference_model.label} counted the last prompt"
  end

  # ActiveSupport's own, not the Rails helper: this renders over the cable as
  # well as in a request, and a phlex-rails adapter reaches for a view context
  # that isn't there. Same constraint the class comment states.
  def exact(tokens) = ActiveSupport::NumberHelper.number_to_delimited(tokens)

  # Thousands as "12.4k". The pair has to fit beside a bar on a phone, and the
  # digits below the thousand never decide anything here.
  def compact(tokens)
    return tokens.to_s if tokens < 1000

    "#{(tokens / 1000.0).round(1).to_s.delete_suffix('.0')}k"
  end
end
