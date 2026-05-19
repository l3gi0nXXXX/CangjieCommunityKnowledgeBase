# CangjieCommunityKnowledgeBase

This project is an independent Cangjie `cjpm` implementation of the Cangjie
community knowledge-base side of the Metis/GitCode monitor bridge plan. It does
not depend on Metis internals and does not perform real network access unless a
caller injects a real `SourceFetchRunner`.

## Source Scope

The default source scope covers:

- `cangjie`, `cangjie-sig`, and `cangjie-tpc` all public repositories.
- `https://cangjie-lang.cn/`, official documentation entry points, and
  `https://docs.cangjie-lang.cn/docs/1.0.0/`.
- `std` and `stdx` documentation.
- Issue and PR history for community evidence.
- Governed web candidates that remain in candidate review by default.

Private repositories, credentials, unredacted logs, and unreviewed web
candidates are excluded from automatic trusted evidence.

## Storage

`FileKnowledgeStore` persists the required logical layout:

- `data/raw`
- `data/normalized`
- `data/metadata`
- `data/indexes`
- `data/derived`
- `data/cache`

Runtime CLI writes generated data under `target/ckb-data` by default. Doctor and
status output report logical `data/...` paths and counts, but never expose local
mirror or absolute host paths to Metis-facing evidence output.

Raw records are normalized into records that retain `sourceUrl`, `repo`,
`commit`, `path`, `symbol`, crawl/index timestamps, `knowledgeVersion`,
`trustLevel`, `reviewState`, `license`, and derived-source references. Index
rebuilds write a candidate version first and only promote it to active after a
successful build, so failed candidates do not pollute active query results.
Status and metadata include deterministic text, vector-surrogate, symbol, and
graph index manifest entries. Candidate indexes remain isolated until publish.

## Source Sync

`SourceAdapter` defines the CKB source boundary for GitCode org/repo/source,
Issue/PR history, official website/docs, and governed web candidates. The
default runner returns `network_disabled`. Tests use `FakeSourceFetchRunner` to
keep offline source-adapter coverage while preserving the production injection
point for real HTTP/Git fetch code.

`SourceRequestBuilder` owns the production request specs used by the sync
surface: GitCode `/api/v5` org repo enumeration, repo metadata, source file raw
content, issue history, PR history, Cangjie website/docs probes, and web
candidate recrawls. `SourceResponseNormalizer` converts injected runner output
into a stable fetch result with status code, normalized type, source URL, and
truncation metadata before ingestion.

## Query Surface

The Cangjie API surface is implemented as MCP/HTTP-like functions:

- `cangjie_source_search`
- `cangjie_doc_search`
- `cangjie_website_search`
- `cangjie_web_candidate_search`
- `cangjie_hybrid_search`
- `cangjie_evidence_pack`
- `cangjie_knowledge_status`

`CkbSchema.mcpTools()` and `CkbSchema.httpLikeRoutes()` expose the current
contract names for bridge callers, including the production health, status,
query, evidence, sync, and rebuild boundary used by Metis-facing integration.
`QueryService` supports `source`, `doc`, `website`, `web_candidate`, `hybrid`,
`evidence_pack`, and `status` modes with budget, truncation, citation, trust,
review-state, and candidate filters.

## Scheduler and Freshness

The baseline scheduler uses a fake clock and encodes the required SLA:

- website and docs probe every 6 hours, with daily full sync placeholders;
- repository list every 6 hours;
- active repository fetch every 30 minutes;
- active issue or PR item sync every 10 minutes;
- web candidate weekly search and 30-day recrawl;
- weekly full rebuild.

`SchedulerExecutor` runs due entries through a task runner and checkpoints
last success, last failure, cursor, since, active version, and candidate
version under `metadata/scheduler.ckb`. Failures retry with 5, 15, then
60-minute backoff; after three failures the entry is marked degraded. The
`metrics` command summarizes storage, backend, stale schedule, and degraded
schedule counts.

Scoped freshness policies are modeled as `use_active`, `ensure_recent`,
`ensure_ref`, and `force_candidate`. Candidate evidence requires review and
repo-scoped refreshes observe a five-minute cooldown.

## Service Lifecycle and Operations

The production service shape is `ckb-stdio-v1`: the executable starts with
`service` or `start`, loads only the explicit `--config` and `--store` paths,
then reads newline-delimited commands from stdin and writes redacted key-value
responses to stdout. It exposes `health`, `status`, `metrics`, `query`,
`evidence`, `sync`, `rebuild`, `scheduler-run`, `backup`, `restore`,
`restart`, and `stop`. This is the stable service interface until a socket
server is selected for deployment.

Backup and restore operate on the active snapshot files only. Restore validates
the backup active snapshot before replacing the target store; malformed or
missing active snapshots return a clear diagnostic such as
`malformed_active_index` without silently promoting corrupted data.

## ACP Offline Curation

The curation queue models repo summary tasks with `pending`, `running`,
`succeeded`, `failed`, and `cancelled` lifecycle states. Derived knowledge can
only be completed when source references are present.

## CLI

The executable supports human-readable commands:

- `doctor`
- `status`
- `metrics`
- `service`
- `service-once <command>`
- `scheduler-run`
- `sync-once`
- `rebuild-index`
- `backup <path>`
- `restore <path>`
- `query <text>`
- `evidence <text>`
- `schema`

Default output is formatted text, not raw JSON.
