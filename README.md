# README

Archyve is a web app that makes pretrained LLMs aware of a user's documents, while keeping those documents on the user's own devices and infrastructure.

<img src="app/assets/images/archyve_font.svg" width=100>

## Overview

Archyve enables Retrieval-Augmented Generation (RAG) by providing an API to query the user's docs for relevant context. The client provides the prompt the user gave, and Archyve will return relevant text chunks.

Archyve provides:

- a document upload and indexing UI, where the user can upload documents and test similarity searches against them
- a built-in LLM chat UI, so the user can test the effectiveness of their documents with an LLM
- an API, so the user can provide Archyve search results in dedicated LLM chat UIs

## Getting started

### Dependencies

1. On a Mac ensure you have [brew](https://brew.sh) installed
2. Make sure you have `docker` set up and a "machine" configured and ready to pull and run container images.
3. Ensure you have [ops](https://github.com/nickthecook/crops?tab=readme-ov-file#installation) installed

### Develop

To start working / developing with Archyve locally, assuming dependencies are good:

1. Install [Ollama](https://ollama.com/) and make sure you're running `ollama serve` and that you have the minimum models installed (see section on Ollama further below).
2. Clone this repo
3. `ops up`
4. `ops rails db:setup`
5. `ops rails server`
6. Go to `http://127.0.0.1:3300/` and you can login using `admin@archyve.io` and `password` to get started.

### Build

To run Archyve, use `docker compose`.

> Podman compose will work as well, if you edit the compose file so that Archyve can connect to ollama on `localhost`.

1. Clone this repo
2. `cp dotenv_template local.env`
3. Run `openssl rand -hex 64` and put the value in the `SECRET_KEY_BASE` variable in your `local.env` file
4. Run the container

```bash
docker compose up --build
```

> If you see "✘ archyve-worker Error", don't worry about it. Docker will build the image and run it.

5. Browse to http://127.0.0.1:3300 and log in with `admin@archyve.io` / `password` (you can change these values by setting `USERNAME` and `PASSWORD` in your `local.env` file and restarting the container)

> **WARNING**: The container will write a file with local encryption keys into `config/local`. **If you lose this file**, the application will not be able to decrypt sensitive data within the database (e.g. passwords or API keys), and the database will need to be reset, **losing all data**.
>
> If you want to migrate your database elsewhere, migrate this file along with it.

## Deploy

### Provisioning ModelServers and ModelConfigs

To configure Archyve with a ModelServer (an LLM server with an API), set the environment variable `PROVISIONED_MODEL_SERVERS` to an array like this:

```json
[
  {
    "name": "localhost",
    "url": "http://localhost:11434",
    "provider": "ollama",
  }
]
```

`ollama` is currently the only supported provider.

To configure Archyve with a ModelConfig (a particular LLM), set the environment variable `PROVISIONED_MODEL_CONFIGS` to an array like this:

```json
[
  {
    "name": "mistral:instruct",
    "model": "mistral:instruct",
    "temperature": 0.1,
  },
  {
    "name": "nomic-embed-text",
    "model": "nomic-embed-text",
    "embedding": true,
  }
]
```

If you don't provision at least one model with `embedding: true` and one model without an `embedding` setting, Archyve won't work. However, you can configure these in the Admin UI after starting the app.

### Scheduled jobs

Archyve will schedule some jobs by default. If you want to disable these jobs, set `CONFIGURE_DEFAULT_JOBS` to `false`.

To schedule additional jobs, or override any of the default schedules, set `SIDEKIQ_CRON` to a hash like this:

```json
{
  "clean_api_calls": {
    "cron": "3 * * * *", 
    "class": "CleanApiCallsJob",
    "args": [],
    "description": "Remove ApiCalls older than 14 days from the database",
    "status": "enabled"
  }
}
```

Jobs defined in the `SIDEKIQ_CRON` environment variable will override any default jobs with the same key (e.g. `clean_api_calls` in this example).

In general, you shouldn't need to set any of these except in development.

## API

### Authentication

Archyve provides a ReST API. To use it, you must have:

1. a Client ID (goes in the `X-Client-Id` header in all API requests)
2. an API key (goes in the `Authorization` header after `Bearer `)

> Ensure you have set up `ACTIVE_RECORD_ENCRYPTION` as described above!

_TODO: add this to the UI_

If you are running the app on your host, you can set the `DEFAULT_API_KEY` and `DEFAULT_CLIENT_ID` environment variables. On startup, Archyve will ensure that a client with these credentials exists.

- `DEFAULT_API_KEY` must be a 48-byte value encoded in base64. Generate a key with `openssl rand -base64 48`.
- `DEFAULT_CLIENT_ID` can be any string, but it should be unique to your app. A UUID is recommended.

> If you are running the app via `docker compose` or `podman compose`, set the above two environment variables in your `local.env` file and restart the containers.

> If you are running the app on your host, set the two above environment variables and run `rails db:seed`.

#### Sending authenticated requests

You should be able to send API requests like this:

```sh
curl -v localhost:3300/v1/collections \
  -H "Accept: application/json" \
  -H "Authorization: Bearer <YOUR_API_KEY>" \
  -H "X-Client-Id: <YOUR_CLIENT_ID>"
```

See [archyve.io](https://archyve.io) for more information on the API.

See the next section for setting up Ollama for use by Archyve or **document uploads and chat will fail**.

## Dependencies

### Ollama

> You can run a dedicated instance of Ollama in a container by adding it to the `compose.yaml` file, but it takes a while to pull a chat model, so the default here is to assume you already have an Ollama instance.

Archyve will use a local instance of [Ollama](https://ollama.com/) by default. Ensure you have Ollama installed and running (with `ollama serve`) and then run the following commands to set up your Ollama instance for Archyve:

- fast embedding model: `ollama pull all-minilm`
- better embedding model: `ollama pull nomic-embed-text`
- chat model: `ollama pull mistral:instruct`
- alternative chat model: `ollama pull gemma:7b` (if you intend to use Gemma)

### Embedding models

You can select an embedding model separately for each Collection you create inside Archyve.

To make an embedding model available for use in Archyve, go to the ModelConfig page in the [admin UI](http://127.0.0.1:3300/admin), create a new ModelConfig, and set `embedding` to `true`. The new embedding model should be an option when creating a Collection, or viewing a Collection which has no Documents in it.

> NOTE The default seeds setup `nomic-embed-text` as default embedding model.

Make sure you pull the model in Ollama.

### Summarization model

You can change summarization model by changing `SUMMARIZATION_ENDPOINT` and `SUMMARIZATION_MODEL` in your `local.env` file and restarting the server. If you change these values, make sure the new models are present in Ollama.

> NOTE The default seeds setup `mistral:instruct` as default embedding model.

## Admin UI

There is an admin UI running at http://127.0.0.1:3300/admin. There, you can view and change ModelConfigs and ModelServers if you are logged in as an admin.

There is a link to it in the bottom of the side bar.

## Jobs

Archyve uses a jobs framework called Sidekiq. It has a web UI that you can access at http://127.0.0.1/sidekiq if you are logged in as an admin.

## TurboStream design

In general:

- use a separate channel for each group of things that need to be independently authorized
  - e.g. a user can see their own conversations but not the conversations of other users
  - therefore, we need to use a separate `conversations` channel for each user
  - using user-specific `dom_id`s is not enough: that would prevent User 1 from seeing User 2's updates in their browser, but User 2's data would still be sent to User 1, and viewable in dev tools
  - all Users can see all Collections for now, so we don't need user-specific Collection-related channels
- use helpers to generate channel IDs and dom IDs in case we need to change how it works at some point
  - models: ApplicationRecord#channel_id, ApplicationRecord#dom_id
  - views: ApplicationHelper#channel_id, ApplicationHelper#dom_id
  - controllers: ApplcationController#channel_id, ApplicationController#dom_id



### Streams

Current state:

- [x] collections/index: channel `collections` -> no change
  - [x] shared/collection_list: dom_id `collections` -> no change
  - [x] shared/collection_list_item: dom_id `dom_id(collection)` -> `"#{dom_id(collection)}-list_item`
  - [ ] shared/collection_area: dom_id `collection_area` -> `user_dom_id("collection_area")`
    - [ ] shared/chunks
      - [ ] shared/chunk: dom_id `dom_id(chunk)`
    - [ ] shared/document: dom_id `dom_id(document)`
    - [ ] collection/collection: dom_id `dom_id(collection)`, `dom_id(collection)-documents`
      - [ ] collections/search_form: dom_id `user_dom_id("search_form")`
      - [ ] shared/document (above)
      - [ ] documents/form: dom_id `document_form`
  - [ ] collections/global_search_form: `user_dom_id(global_search_form)`
  - [ ] collections/global_search_results: `user_dom_id(global_search_results)`
- [ ] conversations/index: channel `conversations`, dom_id `conversation_area`
  - [ ] conversations/conversation_list: dom_id `conversations`
    - [ ] conversations/conversation_list_item: dom_id `dom_id(conversation)`
  - [ ] conversations/conversation: dom_id `conversation`, dom_id `messages`
    - [ ] conversations/conversation_form
    - [ ] messages/message: dom_id `dom_id(message)`
    - [ ] messages/form
  - [ ] conversations/no_conversation
