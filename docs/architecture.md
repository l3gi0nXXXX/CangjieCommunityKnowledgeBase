# CangjieCommunityKnowledgeBase Baseline

This project is an independent Cangjie `cjpm` implementation of the Phase 10
knowledge-base baseline. It does not depend on Metis internals and does not
perform real network access in the baseline build.

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

The baseline keeps the required layout:

- `data/raw`
- `data/normalized`
- `data/metadata`
- `data/indexes`
- `data/derived`
- `data/cache`

Doctor/status output reports these logical paths and counts, but never exposes
local mirror or absolute host paths to Metis-facing evidence output.

## Query Surface

The Cangjie API surface is implemented as MCP-like functions:

- `cangjie_source_search`
- `cangjie_doc_search`
- `cangjie_website_search`
- `cangjie_web_candidate_search`
- `cangjie_hybrid_search`
- `cangjie_evidence_pack`
- `cangjie_knowledge_status`

The offline index supports `sourceType`, `trustLevel`, and `reviewState`
filtering. Candidate index publication is separate from the active index; a
failed candidate build does not replace the active version.

## Scheduler and Freshness

The baseline scheduler uses a fake clock and encodes the required SLA:

- website and docs probe every 6 hours, with daily full sync placeholders;
- repository list every 6 hours;
- active repository fetch every 30 minutes;
- active issue or PR item sync every 10 minutes;
- web candidate weekly search and 30-day recrawl;
- weekly full rebuild.

Scoped freshness policies are modeled as `use_active`, `ensure_recent`,
`ensure_ref`, and `force_candidate`. Candidate evidence requires review and
repo-scoped refreshes observe a five-minute cooldown.

## ACP Offline Curation

The curation queue models repo summary tasks with `pending`, `running`,
`succeeded`, `failed`, and `cancelled` lifecycle states. Derived knowledge can
only be completed when source references are present.
