# frozen_string_literal: true

class Views::Settings::Agents::Form < Views::Base
  CHOICE = "flex cursor-pointer items-start gap-2.5 text-sm text-muted hover:text-fg transition-colors"
  INPUT = "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint " \
          "outline-none focus:border-accent transition-colors"

  def initialize(agent:, collections:, toolsets:, checked_collection_ids:)
    @agent = agent
    @collections = collections
    @toolsets = toolsets
    @checked_collection_ids = checked_collection_ids
  end

  def view_template
    breadcrumb(*trail, title)

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { title }
      p(class: "mt-1 text-sm text-muted") { "Who it is, what it can do, and who can chat with it." }
    end

    form(action:, method: "post", class: "flex flex-col gap-7") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch") if @agent.persisted?
      errors if @agent.errors.any?

      name_field
      prompt_field
      toolsets_field
      access_field
      collections_field
      actions
    end
  end

  private

  def page_title = title

  def title = @agent.persisted? ? "Edit #{@agent.name_was}" : "New agent"

  def trail
    crumbs = [["Settings", settings_path], ["Agents", settings_agents_path]]
    crumbs << [@agent.name_was, settings_agent_path(@agent)] if @agent.persisted?
    crumbs
  end

  def action = @agent.persisted? ? settings_agent_path(@agent) : settings_agents_path

  def name_field
    field("Name") do
      input(type: "text", name: "agent[name]", value: @agent.name, required: true, autofocus: @agent.new_record?, class: INPUT)
    end
  end

  def prompt_field
    field("Prompt", "Its voice, identity and purpose. Each toolset adds the rules its tools depend on, and the instance purpose goes last.") do
      textarea(
        name: "agent[prompt]", rows: "5",
        data: { controller: "autogrow", action: "input->autogrow#resize" },
        class: "#{INPUT} resize-none overflow-y-hidden"
      ) { @agent.prompt }
    end
  end

  def toolsets_field
    field("Toolsets", "Who can chat is limited to people the most restricted toolset allows.") do
      input(type: "hidden", name: "agent[toolset_keys][]", value: "")
      div(class: "flex flex-col gap-2.5") do
        @toolsets.each do |toolset|
          choice("checkbox", "agent[toolset_keys][]", toolset.key, @agent.toolset_keys.include?(toolset.key),
            toolset.label, "#{toolset.description} #{Views::Settings::Agents::Index::FLOORS.fetch(toolset.role_floor)}.")
        end
      end
    end
  end

  def access_field
    field("Who can chat with it") do
      div(class: "flex flex-col gap-2.5") do
        access_choice("everyone", "Everyone", "Anyone the toolsets allow.")
        access_choice("granted", "People granted access", "Chosen on its People page once it's saved.")
        access_choice("creator_only", "Only #{creator_name}", "Nobody else can chat with it, admins included.")
      end
    end
  end

  def creator_name = @agent.creator&.email_address || "you"

  def access_choice(value, label_text, hint)
    choice("radio", "agent[access_mode]", value, @agent.access_mode == value, label_text, hint)
  end

  def collections_field
    field("Draws on", "Only matters with the Archive toolset.") do
      div(class: "flex flex-col gap-2.5") do
        choice("radio", "agent[collection_mode]", "user", @agent.user_collections?,
          "What the person chatting can read", "They can narrow it when they start a chat.")
        choice("radio", "agent[collection_mode]", "fixed", @agent.fixed_collections?,
          "These collections", "Shared with everyone who can chat with it, so you need to manage each one you add.")
        collection_list
      end
    end
  end

  def collection_list
    input(type: "hidden", name: "agent[collection_ids][]", value: "")
    return p(class: "ml-6 text-xs text-faint") { "There are no collections yet." } if @collections.empty?

    div(class: "ml-6 flex flex-wrap gap-2") do
      @collections.each do |collection|
        label(class: "inline-flex cursor-pointer items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs text-muted hover:border-line-2 hover:text-fg transition-colors") do
          input(type: "checkbox", name: "agent[collection_ids][]", value: collection.id,
            checked: @checked_collection_ids.include?(collection.id), class: "accent-accent")
          plain collection.name
        end
      end
    end
  end

  def choice(type, name, value, checked, label_text, hint)
    label(class: CHOICE) do
      input(type:, name:, value:, checked:, class: "mt-1 h-3.5 w-3.5 accent-accent")
      span do
        span(class: "block text-fg") { label_text }
        span(class: "block text-xs text-faint") { hint }
      end
    end
  end

  def field(label_text, hint = nil)
    div do
      p(class: "text-sm font-medium text-fg") { label_text }
      p(class: "mt-0.5 mb-2 text-xs text-faint") { hint } if hint
      div(class: hint ? nil : "mt-2") { yield }
    end
  end

  def errors
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-4 py-3") do
      p(class: "text-sm font-medium text-red-300") { "This agent couldn't be saved." }
      ul(class: "mt-1.5 list-disc pl-4 text-sm text-red-300/80") do
        @agent.errors.full_messages.each { |message| li { message } }
      end
    end
  end

  def actions
    div(class: "flex items-center gap-3") do
      button(type: "submit", class: button_class(:solid)) { @agent.persisted? ? "Save" : "Create agent" }
      a(href: @agent.persisted? ? settings_agent_path(@agent) : settings_agents_path,
        class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
    end
  end
end
