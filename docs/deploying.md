# Deploying Archyve

This section contains information for people deploying Archyve in a production environment.

## Provisioning ModelServers and ModelConfigs

To configure Archyve with a ModelServer (an LLM server with an API), set the environment variable `PROVISIONED_MODEL_SERVERS` to an array like this:

```json
[
  {
    "name": "localhost",
    "url": "http://localhost:11434",
    "provider": "ollama"
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
    "temperature": 0.1
  },
  {
    "name": "nomic-embed-text",
    "model": "nomic-embed-text",
    "embedding": true
  }
]
```

If you don't provision at least one model with `embedding: true` and one model without an `embedding` setting, Archyve won't work. However, you can configure these in the Admin UI after starting the app.

## Scheduled jobs

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

## Job concurrency

By default, Archyve will use 5 threads to run non-LLM jobs (jobs that won't hit an LLM server API) at a time, and 5 LLM jobs at a time. You may need to **change the LLM job concurrency** if you get throttled by the LLM server (e.g. OpenAI).

To change this value, change the value of `LLM_JOBS_CONCURRENCY` in your `.env` file.
