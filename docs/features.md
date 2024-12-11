# Planned Development

## Knowledge Graph
### [ ] Entity Extraction
### [ ] Graph-based Augmentation
### [ ] Community Detection
#### [ ] Automatic Collection Selection\*

This would use the KG to decide which collections to search based on matching the user's prompt to communities.

This may be superseded by "Let Archyve direct searches", if that proves reliable enough to select Collections on its own.

### [x] Relevant Entity Search
### [ ] Relationship search
### [x] Manage Job Parallelism

## OPP
### [x] Ollama Support
### [x] Prompt Augmentation
#### [x] Live UI Updates from OPP
### [x] OpenAI compatibility

Via Ollama's OpenAI compatibility.

### [ ] OpenAI Support

Actually send OPP queries to OpenAI backend when client asks for an OpenAI model, or when Settings indicate.

### [ ] Automatic Collection Selection

This will likely be implemented via the Identity feature "Let Archyve direct searches".

## SSO
### [ ] KeyCloak Support?
### [ ] EntraID Support

## RAG
### [ ] Website scraping

- [x] Fetch Document from web given URL
- [ ] Support non-HTML docs from URLs
- [ ] Follow links to scape larger set of webpages, starting from given URL

## Identity
### [ ] Add Archyve system prompt

The default prompt should have Archyve act as a librarian. It should be aware that it has access to Collections and is trying to respond to provide the user with relevant references from its library,

It should aim for brevity, not chattiness, and minimize "flavour" in its responses.

### [ ] Support tool use

Also limit models to those which support tool use.

### [ ] Let Archyve direct searches

- [ ] Make Archyve aware of what Collections are available to it in its system prompt, and possibly what Documents are in each.
- [ ] Make tools available to Archyve that will search Collections.
- [ ] Instead of augmenting context prior to sending user prompt to LLM, allow Archyve to use search tools when required.
