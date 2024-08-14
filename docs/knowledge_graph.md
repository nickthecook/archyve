# Knowledge Graph

Archyve's Knowledge Graph feature extract entities from documents the user uploads, summarizes them, identifies groupings of entities, and uses this knowledge of entities and communities to augment chat prompts.

It is based on the work in [Microsoft's Graph RAG project](https://github.com/microsoft/graphrag). The prompts used by Archyve to instruct LLMs to extract entities, summarize descriptions, etc. are all based on prompts from that project.

## System overview

Components and connections added for the Knowledge Graph feature are in red.

```plantuml
digraph knowledge_graph {
  node [shape=box]
  edge [fontsize=10]
  rankdir=LR

  User [shape="doublecircle"]
  Archyve

  {
    node [shape=cylinder]

    Postgres
    Redis
    ChromaDB
    Neo4j [color=red fontcolor=red]
  }

  User -> Archyve [dir=both]
  Archyve -> Redis [label="Cache" dir=both]
  Archyve -> Postgres [label="SQL DB" dir=both]
  Archyve -> ChromaDB [label="Similarity\nsearch" dir=both]
  Archyve -> Neo4j [label="Graph DB" dir=both color=red fontcolor=red]
}
```

## Job pipeline architecture

Archyve is a Rails app that uses the Sidekiq jobs framework.

The ingest pipeline within Archyve follows a pattern:

1. The user performs an action (e.g. uploading a document)
2. Archyve enqueues a job
3. The job runs a Service (from `/app/services`) and optionally enqueues another job

This pattern allows multi-stage job pipelines to process documents and collections, while only retrying any failed jobs instead of starting over.

### Ingest pipeline

Red boxes are Jobs, blue boxes are Services.

```plantuml
digraph ingest_pipeline {
  node [shape=box]
  edge [fontsize=10]

  {
    node [color=red]

    IngestJob ExtractDocumentEntitiesJob SummarizeCollectionJob GraphCollectionJob
  }

  {
    node [color=blue]

    TheIngestor ExtractDocumentEntities SummarizeCollectionEntities GraphCollectionEntities

    TheIngestor -> TheIngestor [label="chunk and embed\ndocument content"]
    ExtractDocumentEntities -> ExtractDocumentEntities [label="extracts entity descriptions\nfrom document chunks"]
    SummarizeCollectionEntities -> SummarizeCollectionEntities [label="summarizes entities based\non extracted entity descriptions"]
    GraphCollectionEntities -> GraphCollectionEntities [label="creates a graph of extracted\nentities and their relationships\nin Neo4j"]
  }

  DocumentsController -> IngestJob [label="  enqueue"]
  IngestJob -> TheIngestor [label="execute"]
  IngestJob -> ExtractDocumentEntitiesJob [label="  enqueue"]
  ExtractDocumentEntitiesJob -> ExtractDocumentEntities [label="execute"]
  ExtractDocumentEntitiesJob -> SummarizeCollectionJob [label="  enqueue"]
  SummarizeCollectionJob -> SummarizeCollectionEntities [label="execute"]
  SummarizeCollectionJob -> GraphCollectionJob  [label="  enqueue"]
  GraphCollectionJob -> GraphCollectionEntities [label="execute"]

  rank=same { IngestJob TheIngestor }
  rank=same { ExtractDocumentEntitiesJob ExtractDocumentEntities }
  rank=same { SummarizeCollectionJob SummarizeCollectionEntities }
  rank=same { GraphCollectionJob GraphCollectionEntities }
}
```

## Querying Neo4j

You can query the graph database directly from the Neo4j web UI. It's at [http://localhost:7474](http://localhost:7474) in dev.

To graph all nodes in the database:

```neo4j
match (n) return (n)
```

To graph nodes from one Archyve Collection, called "Greek Mythology":

```neo4j
match (n:`Nodes::Entity` {collection_name: "Greek Mythology"}) return (n)
```

To remove all nodes from the database:

```neo4j
match (n) detach delete (n)
```

To remove nodes from just one Collection:

```neo4j
match (n:`Nodes::Entity` {collection_name: "Greek Mythology"}) detach delete (n)
```
