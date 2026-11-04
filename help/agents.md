# Agents

An Agent in Archyve comprises:

- a prompt which defines the agent's identity and purpose
- a minimum access role
- optionally, a set of Collections from which the agent can search

Agents can be used to create assistants for specific purposes, like an agent just to answer questions about household appliances or HR policies.

This can help users who wouldn't know what collections to select to find a certain answer - they can just select the appropriate agent and ask it. This can also help admins, who can define separate prompts for each agent, if that agent requires special context or instructions.

## Built-in Agents

Archyve comes with built-in agents:

- Archivist: searches the archive and answers user questions
- Admin Support: helps admins diagnose issues with an instance of Archyve itself

These built-in agents cannot be modified or deleted through the UI, but they can be duplicated, so a user could have their own modified copy of the agent.

## Access

Archyve determines whether a user has access to an agent in a few steps:

- Minimum role requirement: the Admin Support built-in agent can only be used by Admins.
- User grant: if the agent is set to "granted-only" access, the user must have a grant on that agent
- Creator allowance: if the user created the agent, the user can always use it

If a user is allowed to use an Agent, it will appear as an option when the user is starting a new chat.

## Default agent

There is always one default agent in Archyve. This is the agent that is selected in new chats by default, and the chat field on the landing page goes to this agent.

An admin can change the default agent. In order to be eligible, an agent must have its Access Mode set to "Everyone".

The default agent can be changed from the [Settings › Agent](/settings/agents) page.

## Prompt

When using an agent, the prompt that will be sent to the model consists of:

- Agent prompt (e.g. "You are Phil, an assistant that...")
- Toolset instructions (e.g. "Search the archive using..." for Archivist)
- Instance purpose (e.g. "This is a document repository that...")

in that order.

Instance purpose can be set in [Settings › Agent](/settings/agents), and the agent prompt can be set on that agent's settings page.

Toolset instructions cannot be modified: they come with the tools.
