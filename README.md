# CangjieCommunityKnowledgeBase

An independent Cangjie `cjpm` baseline for the Cangjie community knowledge base.
The default implementation is offline unless a config enables network access:
it provides deterministic source scope, storage layout, normalization,
simplified text/symbol/hybrid search, evidence-pack APIs, scheduler execution,
service lifecycle, backup/restore, scoped freshness policies, and ACP-style
offline curation lifecycle tests.

## Layout

- `src/`: Cangjie implementation and CLI entrypoint.
- `test/`: Cangjie unittest coverage for the Phase 10 baseline.
- `docs/`: architecture and operating notes.
- `data/`: required knowledge storage layers.
- `LICENSE`: project license.

## Build and Test

```bash
source /Users/l3gi0n/cangjie100/envsetup.sh
cjpm clean
cjpm build -i
cjpm test
```

## CLI

```bash
cjpm run --run-args doctor
cjpm run --run-args metrics
cjpm run --run-args "query func named parameters"
cjpm run --run-args "evidence HttpClient"
cjpm run --run-args "service-once health"
cjpm run --run-args "backup target/ckb-active-copy"
```

The `doctor` command reports logical storage paths, source-scope coverage,
index counts, and scheduler state. It does not expose local mirror paths.

## Service Protocol

CKB can run as a long-lived stdio service:

```bash
cjpm run --run-args "--config ckb.conf --store target/ckb-data service"
```

The service prints one key-value response per command. Supported commands are:
`health`, `status`, `metrics`, `query <text>`, `evidence <text>`, `sync`,
`rebuild`, `scheduler-run`, `backup <path>`, `restore <path>`, `restart`, and
`stop`. `stop` performs a graceful exit. `restart` reloads the active snapshot
from the configured `--store`. No user home files are read unless an explicit
`--config` path names them; token values and absolute local paths are redacted
from human-facing output.

## API Surface

The core MCP-like functions are available from `src/core.cj`:

- `cangjie_source_search`
- `cangjie_doc_search`
- `cangjie_website_search`
- `cangjie_web_candidate_search`
- `cangjie_hybrid_search`
- `cangjie_evidence_pack`
- `cangjie_knowledge_status`

Web candidate evidence is always marked `requiresReview=true` by default.

## Contribution Rules

Keep knowledge synchronization, storage, indexing, and evidence-pack lifecycle
inside this project. Do not generate final GitCode replies here; Metis owns
reply generation. Do not scan GitCode monitor cursors or write GitCode comments
here; GitCodeMonitor owns that lifecycle.
