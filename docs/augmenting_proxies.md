# Transparent Augmenting Proxy (TAP)

Archyve includes an Ollama proxy, which forwards all requests it receives to the active Ollama server. If the request is a chat request (i.e. is sent to the path `/api/chat`) then Archyve will augment the last prompt in the chat before sending it to the server.

Proxied requests are visible in the Conversation view in Archyve.

## Compatibility

TAP is compatible with any Ollama client that supports chunked responses (i.e. "streamed" responses). It has been tested, and works, with:

- `ollama` CLI
  - `OLLAMA_HOST=localhost:11337 ollama run llama3.1:latest`
- OpenWebUI
- `curl`, using ollama-compatible JSON payloads
  - `ops opp -p payloads/ollama/chat.json api/chat`

## Transparency

The feature is called "_Transparent_ Augmenting Proxy" because it's meant to be undetectable to clients, aside from augmented prompts.

However, the Ollama Proxy will, unlike Ollama, always return a chunked response. If the client specifies `stream: false` in the body, they will get a single chunk back with the complete response, instead of multiple chunks with a partial response in each, but the response will technically be a chunked response. This may break some clients.
