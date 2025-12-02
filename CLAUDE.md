# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Archyve is a Rails 7 web application that enables Retrieval-Augmented Generation (RAG) by providing document ingestion, vectorization, and search capabilities. It keeps user documents on their own infrastructure while making pretrained LLMs aware of those documents. The app supports both traditional RAG and experimental Knowledge Graph (Graph RAG) features.

## Development Commands

### Setup
```bash
# Install dependencies (uses ops tool for dependency management)
ops up

# Database setup
ops rails db:setup
ops rails neo4j:migrate

# Start all services (Rails server, Tailwind CSS, Sidekiq workers, OPP)
ops server
```

### Testing
```bash
# Run unit/integration tests (excludes e2e tests)
ops test
# or alias: ops t

# Run specific test file
ops rails rspec spec/path/to/spec.rb

# Run tests in watch mode
ops test-watch
# or alias: ops tw

# Run end-to-end tests (requires TEST_E2E=true)
ops test-e2e
# or alias: ops e2e

# Run e2e tests in watch mode
ops test-e2e-watch
# or alias: ops ew
```

### Linting
```bash
# Run RuboCop
ops lint

# Run linting in watch mode
ops lint-watch
# or alias: ops lw

# Auto-fix issues
bundle exec rubocop -a
```

### Database
```bash
# Run migrations (both PostgreSQL and Neo4j)
ops migrate

# Rails console
ops rails console

# REPL
ops repl
```

### API Requests
```bash
# Send authenticated API requests (handles auth headers automatically)
ops request search q=hello
ops request collections/1/entities/1
ops request version
# or alias: ops r

# Request to OPP proxy
ops opp
```

## Architecture Overview

### Core Components

**Models:**
- `Collection`: Groups of documents for semantic search; each has an embedding model and optional entity extraction model
- `Document`: Files uploaded by users; go through state transitions (created → converting/fetching → chunking → chunked)
- `Chunk`: Text segments from documents with embeddings stored in ChromaDB
- `GraphEntity` / `GraphRelationship`: Knowledge Graph entities and their relationships, stored in Neo4j
- `Conversation` / `Message`: Chat interactions between users and LLMs
- `ModelServer`: LLM servers (Ollama, OpenAI, Azure OpenAI)
- `ModelConfig`: Specific models available on ModelServers (chat models vs embedding models)

**State Machines:**
Documents and Collections use AASM gem for state transitions. Documents progress through: created → converting → converted → chunking → chunked. Collections with Knowledge Graph enabled progress through: created → summarizing → summarized → vectorizing → vectorized → graphing → graphed.

### Document Processing Pipeline

The `Mediator` service orchestrates document ingestion by determining the next step:
1. **Fetch** (web documents): `FetchWebDocumentJob` downloads remote content
2. **Convert** (non-text formats): `ConvertDocumentJob` converts PDFs/DOCX to text via `Converters::*` services
3. **Chunk** (text extraction): `ChunkDocumentJob` splits documents into chunks via `Chunkers::*` services
4. **Embed** (vectorization): `EmbedChunkJob` generates embeddings and stores in ChromaDB
5. **Extract** (Knowledge Graph only): `ExtractDocumentEntitiesJob` uses LLM to identify entities/relationships
6. **Summarize** (Knowledge Graph only): `SummarizeEntityJob` creates entity summaries
7. **Vectorize** (Knowledge Graph only): Entity summaries are embedded and stored in ChromaDB
8. **Graph** (Knowledge Graph only): `GraphCollectionJob` pushes entities/relationships to Neo4j

### LLM Client Architecture

`LlmClients::Client` is the abstract base class with provider-specific implementations:
- `LlmClients::Ollama::Client`: Local Ollama support
- `LlmClients::Openai::Client`: OpenAI API support
- `LlmClients::Openai::AzureClient`: Azure OpenAI support

These clients handle chat completions, embeddings, and streaming responses.

### Job Processing

Sidekiq handles background jobs with two queues:
- **default queue**: General operations (chunking, document creation/deletion)
- **llm queue**: LLM-intensive operations (embedding, entity extraction, chat) with configurable concurrency via `LLM_JOBS_CONCURRENCY`

Jobs are in `app/sidekiq/` and follow the naming convention `*_job.rb`.

### ChromaDB Integration

`Chromadb::Client` (in `app/lib/chromadb/`) manages vector database operations:
- Creates collections for documents and entity summaries
- Stores embeddings with metadata
- Performs similarity searches
- Each Archyve Collection maps to two ChromaDB collections: one for chunks, one for entity summaries (if KG enabled)

### Knowledge Graph (Experimental)

When enabled on a Collection:
- `Graph::EntityExtractor` prompts LLM to extract entities and relationships from chunks
- `Graph::EntitySummarizer` creates summaries of entities based on all mentions
- Entity summaries are embedded and stored in ChromaDB for semantic search
- Entities and relationships are pushed to Neo4j for graph queries
- Access Neo4j web interface at http://localhost:7474 (neo4j/password)

### API

API controllers are in `app/controllers/v1/`. Authentication uses Bearer tokens (API key) and `X-Client-Id` headers. The `ApiController` base class handles auth. Key endpoints:
- `/v1/search`: Similarity search across collections
- `/v1/chat`: Chat with augmented context
- `/v1/collections`: CRUD operations on collections
- `/v1/collections/:id/documents`: Document management
- `/v1/collections/:id/entities`: Knowledge Graph entities

### Ollama Augmenting Proxy (OPP)

The OPP is a drop-in replacement for Ollama that automatically augments prompts with relevant context from Archyve. It runs on a separate port (11337 by default) and intercepts Ollama API calls. Controllers in `app/controllers/ollama_proxy/` handle request forwarding and prompt augmentation.

### Real-time Updates

Uses Hotwire Turbo Streams for live UI updates. Models broadcast changes via `after_*_commit` callbacks:
- Document state changes broadcast to collections channel
- Collection state changes broadcast to collection list items
- Message creation broadcasts to conversation streams

## Key Configuration Files

- `ops.yml`: Development workflow automation (dependencies, commands, environment)
- `config/dev/config.json`: Local development configuration (models, secrets, environment vars)
- `compose.yaml`: Docker Compose services (PostgreSQL, Redis, ChromaDB, Neo4j, Archyve web/workers)
- `Procfile.dev`: Process definitions for `overmind` (web, CSS, Sidekiq workers, OPP)

## Testing

Specs are organized by type:
- `spec/models/`: Model unit tests
- `spec/services/`: Service object tests
- `spec/requests/`: Controller/API tests
- `spec/jobs/`: Background job tests
- `spec/e2e/`: End-to-end tests (require `TEST_E2E=true`)

Use `factory_bot_rails` for test data. E2E tests may use instance variables (RuboCop exception in place).

## Common Patterns

**Service Objects:** Most business logic lives in service classes under `app/services/`. They typically have a `call` or `execute` method.

**Job Enqueueing:** Use `JobClass.perform_async(args)` for Sidekiq jobs. LLM-intensive jobs should go to the `llm` queue.

**ChromaDB Collections:** Collection names follow the pattern `{collection_id}-{collection_slug}` for document chunks and `{collection_id}-{collection_slug}-entities` for entity summaries.

**Error Handling:** Custom error classes are defined within service/lib classes (e.g., `Mediator::IngestError`).

## Database

- **PostgreSQL**: Primary database for application data
- **Neo4j**: Graph database for Knowledge Graph entities/relationships (experimental feature)
- **ChromaDB**: Vector database for embeddings (document chunks and entity summaries)
- **Redis**: Session store and Sidekiq queue backend

## Environment Variables

Key environment variables (set in `config/dev/config.json` for local dev or `local.env` for Docker):
- `DATABASE_URL`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`: PostgreSQL connection
- `REDIS_URL`: Redis connection (default: redis://localhost:6378/1)
- `NEO4J_URL`, `NEO4J_USERNAME`, `NEO4J_PASSWORD`: Neo4j connection
- `CHROMADB_URL`: ChromaDB connection (default: http://localhost:8000)
- `DEFAULT_API_KEY`, `DEFAULT_CLIENT_ID`: Default API credentials
- `LLM_JOBS_CONCURRENCY`: Sidekiq llm queue concurrency (default: 5)
- `SECRET_KEY_BASE`: Rails secret (generate with `openssl rand -hex 64`)
- `PORT`: Web server port (default: 3300)
- `OPP_PORT`, `OPP_BIND_ADDRESS`: Ollama Proxy port and bind address
