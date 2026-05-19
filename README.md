# CangjieCommunityKnowledgeBase

## Project Introduction

CangjieCommunityKnowledgeBase is an independent Cangjie community knowledge
service. It owns the lifecycle for Cangjie source code, documentation, community
history, normalized records, indexes, derived knowledge, evidence packs, and
knowledge versions.

Metis consumes evidence from this service when generating GitCode summaries and
reply drafts. GitCodeMonitor remains responsible for GitCode scanning,
notification delivery, and writeback.

The current baseline is an offline-testable Python package. It provides source
scope configuration, storage layout creation, raw record models, normalization,
simple indexes, evidence-pack query functions, knowledge status, bootstrap sync
with fake adapters, update scheduler defaults, offline curation queue, and
scoped just-in-time refresh primitives for ACP long-running tasks.

## Usage

Requirements:

- Python 3.9 or newer.
- No third-party runtime dependency is required for the current baseline.

Run tests:

```bash
PYTHONPATH=src python3 -m compileall -q src tests
PYTHONPATH=src python3 -m unittest discover -s tests -v
```

Example usage:

```python
from cangjie_community_knowledge_base import (
    CangjieKnowledgeBase,
    cangjie_evidence_pack,
    cangjie_knowledge_status,
)

kb = CangjieKnowledgeBase("/tmp/cangjie-knowledge")
status = cangjie_knowledge_status(kb)
print(status["storageLayout"])

pack = cangjie_evidence_pack(kb, "stdx HTTP client")
print(pack["knowledgeVersion"])
```

A real deployment should provide source adapters for GitCode, official Cangjie
documentation, website pages, and reviewed web candidates.

## Quick Start

```bash
cd /Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase
PYTHONPATH=src python3 -m compileall -q src tests
PYTHONPATH=src python3 -m unittest discover -s tests -v
```

The default source scope includes:

- `cangjie`
- `cangjie-sig`
- `cangjie-tpc`
- Cangjie website and documentation roots
- Standard library repositories
- Issue and pull request history
- Governed web candidates

The storage layout is created under the configured root:

```text
data/raw
data/normalized
data/metadata
data/indexes
data/derived
data/cache
```

## How to Contribute

1. Keep knowledge synchronization, storage, indexing, and evidence-pack
   lifecycle in this project.
2. Do not generate final GitCode replies here; Metis owns reply generation.
3. Do not scan GitCode monitor cursors or write GitCode comments here;
   GitCodeMonitor owns that lifecycle.
4. Preserve source references, `knowledgeVersion`, `trustLevel`, and
   `reviewState` in new data paths.
5. Keep tests offline by using fake source adapters.
6. Add tests for scheduler SLA, storage layout, normalization, search, evidence
   redaction, candidate gating, and scoped refresh.
7. Run validation before committing:

```bash
PYTHONPATH=src python3 -m compileall -q src tests
PYTHONPATH=src python3 -m unittest discover -s tests -v
```
