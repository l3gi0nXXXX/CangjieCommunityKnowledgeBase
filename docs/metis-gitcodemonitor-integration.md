# CKB Metis GitCodeMonitor Integration Runbook

This document defines the production boundary for running
CangjieCommunityKnowledgeBase (CKB) with Metis and GitCodeMonitor. The three
projects remain independently deployed and versioned. Do not copy CKB source,
configuration, stores, credentials, or generated indexes into Metis or
GitCodeMonitor.

## Interface Boundary

CKB exposes a stable contract through its CLI schema output and the equivalent
service bridge names below. `cjpm run --run-args schema` is the executable
contract source for current builds.

| Interface | CLI entry | Service route/tool | Caller | Input | Output |
| --- | --- | --- | --- | --- | --- |
| health | `status` | `GET /health`, `cangjie.health` | Metis, operators | none | `ok`, `status`, `activeKnowledgeVersion`, `degraded` |
| status | `status` | `GET /status`, `cangjie.status` | Metis, operators | none | storage counts, index manifest, scheduler state, `activeKnowledgeVersion`, restore diagnostic |
| query | `query <text>` | `POST /query`, `cangjie.query` | Metis | `q`, `budget`, optional source filters, `includeCandidates=false` by default | ranked evidence rows, citations, `knowledgeVersion`, truncation/degraded flags |
| evidence | `evidence <text>` | `POST /evidence`, `cangjie.evidence` | Metis | `q`, `budget`, `includeCandidates=true` only for reviewed workflows | evidence pack, graph context, citations, `activeKnowledgeVersion` |
| source analysis | `source_analysis repo=<owner/repo> ref=<ref> path=<path> query=<text>` | `POST /source-analysis`, `cangjie.source_analysis` | Metis, operators | `repo`, `ref`, `query`, optional `issueUrl`, `prUrl`, `changedFiles`, `candidatePaths`, `allowCloneFallback`, `maxFiles`, `maxBytes`, `timeoutMillis` | `analysisId`, `triggerReasons`, `sourceAcquisition`, `filesRead`, `citations`, `degraded`, `cleanupStatus` |
| sync | `sync-live --dry-run` or `sync-live --apply` | `POST /sync`, `cangjie.sync` | operators, scheduled CKB runtime | `dryRun`, `apply`, `maxRepos`, `maxFilesPerRepo`, `maxItems`, `since` | source status summary, candidate version, active version, redacted errors |
| rebuild | `rebuild-index` | `POST /rebuild-index`, `cangjie.rebuild` | operators, CKB runtime | store path or default store | candidate version, promoted active version, record count |

All query/evidence results must carry the active or candidate knowledge version
used to produce them. Metis should cite CKB records only when the returned
record contains a non-empty citation or source URL. Web candidate evidence is
not trusted by default and must retain `requiresReview=true` until reviewed.
Failed candidate builds must not replace active indexes.

GitCode live sync is scoped to public repositories only. Private, internal, and
unknown-visibility repositories are not valid CKB knowledge sources and must be
rejected before fetch, normalization, indexing, or evidence publication. The
CKB/Metis/GitCodeMonitor integration contract does not provide any
repository-visibility mode or bypass mode for non-public repositories.

On-demand source analysis is separate from routine `sync-live`. It is triggered
only by explicit source-analysis requests or classifier signals such as compile
errors, runtime bugs, stack traces, mentioned file paths or symbols, PR diffs,
insufficient source evidence, or fresh-source requirements. SRC-0/SRC-1/SRC-2
use API raw reads first and contents reads as fallback. Clone fallback is only a
reported plan/degraded status in this phase; CKB must not create a clone
workspace for normal sync or for API-only source analysis.

## Redaction and Error Contract

CKB must never return or log raw `tokenRef`, raw `tokenFile` contents,
`Authorization` headers, `Cookie` headers, proxy passwords, or absolute local
mirror paths in Metis-facing outputs. Runtime status may report credential
presence as `gitcode.token=present` or `gitcode.token=absent` only.

Service bridges should normalize failures to these codes:

| Code | Meaning | Retry |
| --- | --- | --- |
| `ckb.bad_request` | invalid route input or mutually exclusive sync mode | no |
| `ckb.network_disabled` | runtime network gate is off | no, fix config |
| `ckb.auth_degraded` | GitCode authentication failed or is not implemented for the selected mode | after credential/config fix |
| `ckb.rate_limited` | upstream returned rate limiting or retry-after | yes, honor retry-after |
| `ckb.source_unavailable` | upstream source failed, missing, or timed out | yes with backoff |
| `ckb.rebuild_failed` | candidate index build failed | no active promotion |
| `ckb.validation_failed` | candidate content failed validation | no active promotion |

## GitCodeMonitor Boundary

GitCodeMonitor calls CKB directly only for operator or diagnostic workflows that
need knowledge freshness information, for example checking CKB `health`,
checking `status`, or triggering a controlled `sync --dry-run` before an
acceptance window.

GitCodeMonitor should go through Metis when the workflow includes user-facing
answer generation, issue or PR reply drafting, comment writing, routing policy,
or session context. In that path GitCodeMonitor sends the event to Metis, Metis
queries CKB for evidence, and Metis owns the final response. CKB never scans
GitCode monitor cursors and never writes GitCode comments.

## Three-Project Startup

Run each project from its own checkout or worktree. Replace the Metis and
GitCodeMonitor commands with their project-local production commands.

```bash
# Terminal 1: CKB
cd /path/to/CangjieCommunityKnowledgeBase
source /Users/l3gi0n/cangjie100/envsetup.sh
cjpm build -i
cjpm run --skip-build --run-args "status"
cjpm run --skip-build --run-args "schema"

# Terminal 2: Metis
cd /path/to/Metis
# start Metis with its own config and point only to the CKB route/tool endpoint

# Terminal 3: GitCodeMonitor
cd /path/to/GitCodeMonitor
# start GitCodeMonitor with its own config and point only to Metis for reply workflows
```

Do not add CKB config files, token files, generated stores, or CKB source files
to the Metis or GitCodeMonitor repositories.

## End-to-End Dry Run

1. Build CKB and verify its offline status.

```bash
source /Users/l3gi0n/cangjie100/envsetup.sh
cjpm build -i
cjpm run --skip-build --run-args "status"
cjpm run --skip-build --run-args "query func named parameters"
cjpm run --skip-build --run-args "evidence HttpClient"
```

2. Create a local, ignored runtime config outside committed docs. Use anonymous
   access first unless the acceptance owner provides a credential file for
   public repository API quota or authentication requirements. Do not use
   credentials to acquire private, internal, or unknown-visibility repositories.

```text
network.enabled=true
gitcode.baseUrl=https://api.gitcode.com/api/v5
gitcode.authMode=token
gitcode.authHeader=private-token
gitcode.tokenFile=tokenFile
website.enabled=true
docs.enabled=true
network.timeoutMillis=10000
network.retryCount=2
```

The ignored `tokenFile` contains one GitCode PAT line only. Do not include
`token=`, `Bearer`, `PRIVATE-TOKEN`, quotes, comments, or any other prefix.
For anonymous dry-run smoke, set `gitcode.authMode=none` in the local ignored
config and do not create or read `tokenFile`.

3. Run CKB dry-run sync. It must report source shapes, transport diagnostics,
   auth header strategy, and redacted status without writing raw records.

```bash
cjpm run --skip-build --run-args "--config ckb-live.conf sync-live --dry-run --max-repos 3 --max-items 20"
```

4. Trigger a Metis dry-run request against CKB evidence. Metis must preserve CKB
   citations and active knowledge version in its internal trace.

5. Trigger a GitCodeMonitor dry-run event through Metis. GitCodeMonitor must not
   call CKB for final answer generation and must not write a GitCode comment.

## Controlled Live Acceptance

Use a short window, a small source limit, and an ignored credential file only if
anonymous access is insufficient for public repository sync.

```bash
cjpm run --skip-build --run-args "--config ckb-live.conf sync-live --apply --max-repos 3 --max-files-per-repo 2 --max-items 20"
cjpm run --skip-build --run-args "rebuild-index"
cjpm run --skip-build --run-args "status"
cjpm run --skip-build --run-args "evidence HttpClient"
```

Acceptance requires: active version changes only after successful rebuild,
candidate failures do not replace the active version, evidence retains
citations, candidate evidence stays marked for review, and no output includes
credentials or absolute local paths.

## Log Checks

Check CKB logs or terminal output for sync source status, retry/rate-limit
messages, candidate/active version transitions, and redacted credential status.
Check Metis logs for CKB request IDs and returned knowledge versions. Check
GitCodeMonitor logs for dry-run routing to Metis and absence of write actions
unless the controlled acceptance explicitly enables them.

## Rollback and Stop

Stop GitCodeMonitor first to prevent new inbound events, then stop Metis, then
stop or disable CKB sync. To roll back CKB knowledge, restart CKB with the last
known good store or restore the previous `target/ckb-data` backup before
re-enabling Metis queries. Never roll back by copying CKB generated data into
Metis or GitCodeMonitor.
