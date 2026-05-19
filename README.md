# CangjieCommunityKnowledgeBase

An independent Cangjie `cjpm` baseline for the Cangjie community knowledge base.
The implementation is intentionally offline: it provides deterministic source
scope, storage layout, normalization, simplified text/symbol/hybrid search,
evidence-pack APIs, scheduler SLA modeling, scoped freshness policies, and
ACP-style offline curation lifecycle tests without using real network sources.

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
cjpm run --run-args "query func named parameters"
cjpm run --run-args "evidence HttpClient"
```

The `doctor` command reports logical storage paths, source-scope coverage,
index counts, and scheduler state. It does not expose local mirror paths.

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

Operational integration with Metis and GitCodeMonitor is documented in
`docs/metis-gitcodemonitor-integration.md`. Manual production acceptance is
tracked with `docs/manual-acceptance-checklist.md`.

## Contribution Rules

Keep knowledge synchronization, storage, indexing, and evidence-pack lifecycle
inside this project. Do not generate final GitCode replies here; Metis owns
reply generation. Do not scan GitCode monitor cursors or write GitCode comments
here; GitCodeMonitor owns that lifecycle.
