# README

Archyve is a web app that makes pretrained LLMs aware of a user's documents, while keeping those documents on the user's own devices and infrastructure.

<img src="app/assets/images/archyve_font.svg" width=100>

## Overview

It enables Retrieval-Augmented Generation (RAG) by providing an API to query the user's docs for relevant context. The client provides the prompt the user gave, and Archyve will return relevant text chunks.

Archyve provides:

- a document upload and indexing UI, where the user can upload documents and test similarity searches against them
- a built-in LLM chat UI, so the user can test the effectiveness of their documents with an LLM
- an API, so the user can provide Archyve search results in dedicated LLM chat UIs

## Getting started

To run Archyve, use `docker compose` or `podman compose`.

1. Clone this repo
2. `cp dotenv_template local.env`
3. Run `openssl rand -hex 64` and put the value in the `SECRET_KEY_BASE` variable in your `local.env` file
4. Run the container

```bash
docker compose up --build
```

> If you see "✘ archyve-worker Error", don't worry about it. Docker will build the image and run it.

5. get a shell in the Archyve container with `docker compose exec archyve bash`
6. run `bin/rails db:encryption:init` from within the container

```bash
$ rails db:encryption:init
Running `bin/rails db:encryption:init` in environment 'dev'...
Add this entry to the credentials of the target environment:

active_record_encryption:
  primary_key: PqxwHUF2E3MnPUW3qmOHUikIWJxhvY90
  deterministic_key: wJi0qI8KftvGhqkNh42SaG2oh64ZKIGZ
  key_derivation_salt: sE2nd5xn1rq2YdkDHHxQOuDhcOMfV5jr
```

7. put the values from the output into your `local.env` file

```bash
...
ACTIVE_RECORD_ENCRYPTION="{
  \"primary_key\": \"PqxwHUF2E3MnPUW3qmOHUikIWJxhvY90\",
  \"deterministic_key\": \"wJi0qI8KftvGhqkNh42SaG2oh64ZKIGZ\",
  \"key_derivation_salt\": \"sE2nd5xn1rq2YdkDHHxQOuDhcOMfV5jr\"
}"
```

8.  restart the containers
9.  Browse to http://127.0.0.1:3300 and log in with `admin@archyve.io` / `password` (you can change these values by setting `USERNAME` and `PASSWORD` in your `local.env` file and restarting the container)

See the next section for setting up Ollama for use by Archyve or **document uploads and chat will fail**.

## Dependencies

### Ollama

> You can run a dedicated instance of Ollama in a container by adding it to the `compose.yaml` file, but it takes a while to pull a chat model, so the default here is to assume you already have an Ollama instance.

Archyve will use a local instance of [Ollama](https://ollama.com/) by default. Ensure you have Ollama installed and running (with `ollama serve`) and then run the following commands to set up your Ollama instance for Archyve:

- embedding model: `ollama pull all-minilm`
- chat model: `ollama pull mistral:instruct`
- alternative chat model: `ollama pull gemma:7b` (if you intend to use Gemma)

You can change the embedding model and the summarization model by changing those variables in your `local.env` file and restarting the server. If you change these values, make sure you pull the new models in Ollama.

## Admin UI

There is an admin UI running at http://127.0.0.1:3300/admin. There, you can view and change ModelConfigs and ModelServers.
