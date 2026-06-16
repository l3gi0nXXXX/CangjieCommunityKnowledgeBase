# CKB External Knowledge Service Matrix

This document defines the service-v1 external knowledge capabilities exposed by
CangjieCommunityKnowledgeBase (CKB). It is intended for CKB developers,
operators, Metis/GitCodeMonitor integrators, and third-party clients.

The matrix describes externally callable services. It does not grant additional
permissions beyond each service's authentication and boundary rules.

## Service Capability Matrix

| Capability | API / Entry | Primary callers | Input | Output | Knowledge / data scope | Auth | Writes state | Boundary rules |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Health check | `GET /v1/health` | Any client, Metis, operators | none | `status`, `activeKnowledgeVersion`, `degraded`, `schedulerDegraded` | service availability and active knowledge version | none or read-only access control | no | Must not return local paths, tokens, or authorization headers. |
| Full status | `GET /v1/status` | Any client, Metis, operators | none | storage, indexManifest, scheduler, restoreDiagnostic, activeKnowledgeVersion | active/candidate store, index, scheduler state | none or read-only access control | no | May report credential presence only; must not expose token contents or absolute local paths. |
| Schedule status | `GET /v1/schedules` | Any client, Metis, operators | none | `entries[]` with interval, nextRunAt, lastSuccessAt, failureCount, lastDurationMillis, lastRequestCount, lastUpdatedDataKinds | observable scheduler state | none or read-only access control | no | Read-only observation; this API must not trigger refresh work. |
| API schema | `GET /v1/schema` | Any client, SDKs, scripts, developers | none | routes, tools, errorCodes, apiVersion, limits | HTTP/JSON API contract | none or read-only access control | no | Schema must stay aligned with real handlers. |
| General knowledge query | `POST /v1/query` | Any client, Metis, agents | `q`, `budget`, `sourceType`, `includeCandidates` | ranked rows, citations, knowledgeVersion, truncated | active knowledge from docs, website, source, issues, PRs, comments, and reviewed candidates | none or read-only access control | no | `budget` defaults to 5 and is capped at 20. Downstream clients must not cite rows without citation/source URL. |
| Evidence pack | `POST /v1/evidence-pack` | Metis, agents, external tools | `q`, `budget`, `includeCandidates`, `parentUrl`, `repo`, `ref` | source/doc/website/community/webCandidate evidence, graphContext, citations, knowledgeVersion | structured evidence for answer generation | none or read-only access control | no | Recommended for Metis. `web_candidate` evidence must retain `requiresReview=true`. |
| On-demand source analysis | `POST /v1/source-analysis` | Metis, agents, operators | `repo`, `ref`, `query`, `issueUrl`, `prUrl`, `changedFiles`, `candidatePaths`, `allowCloneFallback`, `maxFiles`, `maxBytes`, `timeoutMillis` | analysisId, sourceAcquisition, filesRead, citations, cleanupStatus, truncated, degraded | selected facts from a public GitCode repo/ref/file scope | none or read-only access control; clone fallback may require stricter runtime config | no persistent knowledge write; temporary source workspaces must be cleaned | Public repositories only. Paths must be repo-relative; absolute paths, `..`, `~`, and backslash escapes are invalid. |
| GitCode repository-change event intake | `POST /v1/events/gitcode/repository-changed` | GitCodeMonitor | `gcm-ckb-repository-change-v1` payload | `eventId`, `status`, `dedupeKey`, `scheduledProfiles`, `acceptedAt`, `diagnostics` | facts from merged PRs that may schedule repo-scoped items/source/repo-list updates | event token | yes, through CKB internal update scheduling | Accept only `provider=gitcode`, `eventType=merge_request`, `reason=pr_merged`. Event token must not access query or admin APIs. |
| Low-change task refresh | `POST /v1/admin/scheduler/run`; restricted Metis operator `/ckb-refresh <target>` mapping | operators, Metis Telegram/Feishu operators | `taskNames`, `force`, `reason`, `requestedBy`, `source` | ran, succeeded, failed, degraded, details, forced, taskNames | only allowlisted low-change tasks | admin token; IM entry also requires operator gate | yes | Allowlist only: `community_repo_discovery_30d`, `docs_probe_30d`, `website_probe_weekly`, `website_full_weekly`, `web_candidate_weekly`, `web_candidate_recrawl_30d`, `weekly_full_rebuild`. Must not trigger on-merge tasks. |
| Single-repository operations refresh | `POST /v1/admin/repositories/sync` | operators, CKB event intake internal reuse | `repo`, `ref`, `profile`, `changedFiles`, `prNumber`, `mode`, `reason` | repo, profile, requestCount, updatedDataKinds, truncated, candidateVersion, activeKnowledgeVersion | source/items/repo_source_and_items for one public repo | admin token; internal event path must not expose admin token | yes | Break-glass operations API. It must not be mapped to Metis Telegram/Feishu `/ckb-refresh`. |
| Repository-list operations refresh | `POST /v1/admin/repo-list/refresh` | operators, CKB event intake internal reuse | `repo`, `ref`, `paths`, `prNumber`, `mode`, `reason` | matchedPaths, repoCount, candidateRepoListVersion, activeRepoListVersion, diagnostics | configured repository list files such as `repo_list.md` and `repo_lists.md` | admin token; internal event path must not expose admin token | yes | Only merged PR changes to repo-list files may promote active repo lists. It must not be mapped to Metis Telegram/Feishu `/ckb-refresh`. |
| Index and storage operations | `/v1/admin/sync`, `/v1/admin/rebuild`, `/v1/admin/restart`, `/v1/admin/backup`, `/v1/admin/restore` | operators | endpoint-specific request body | source status, candidateVersion, activeKnowledgeVersion, backup/restore result | active/candidate store, index, backup state | admin token | yes | Not for ordinary clients. Unauthorized requests must have no side effects. |

## Caller Boundaries

- Ordinary clients and the normal Metis GitCode reply path may use only the
  public read-only APIs: `/v1/query`, `/v1/evidence-pack`, necessary
  `/v1/source-analysis`, and status/schema endpoints.
- GitCodeMonitor may call only
  `/v1/events/gitcode/repository-changed`. It must not call
  `/v1/evidence-pack`, `/v1/source-analysis`, or `/v1/admin/*`.
- Metis Telegram/Feishu `/ckb-refresh` may map only to allowlisted low-change
  scheduler tasks and status queries. It must not map to single-repository
  source/items refresh or repo-list refresh.
- Break-glass admin APIs must require an admin token and must audit `reason`,
  `requestedBy`, `source`, and `requestId`. Responses and logs must not expose
  tokens, authorization headers, proxy credentials, or unredacted local paths.

## Update Trigger Summary

| Update target | Normal trigger | Manual IM trigger | Reason |
| --- | --- | --- | --- |
| `active_item_sync_on_merge` | real merged PR event through `POST /v1/events/gitcode/repository-changed` | not supported | Requires merged-PR facts; manual IM commands do not prove target-branch update. |
| `active_repo_fetch_on_merge` | real merged PR event through `POST /v1/events/gitcode/repository-changed` | not supported | Requires merge commit, target ref, and changed files. |
| `repo_list_refresh_on_merge` | real merged PR event whose changed files match configured repo-list paths | not supported | Active repo list promotion must be tied to merged repo-list file changes. |
| `community_repo_discovery_30d` | CKB scheduler every 30 days | `/ckb-refresh repo-catalog` | Low-change metadata discovery for `cangjie`, `cangjie-sig`, and `cangjie-tpc`. |
| `docs_probe_30d` | CKB scheduler every 30 days | `/ckb-refresh docs` | Low-change official docs entry refresh. |
| `website_probe_weekly` | CKB scheduler every 7 days | `/ckb-refresh website-probe` | Low-change website entry refresh. |
| `website_full_weekly` | CKB scheduler every 7 days | `/ckb-refresh website-full` | Bounded website source refresh. |
| `web_candidate_weekly` | CKB scheduler every 7 days | `/ckb-refresh web-candidates` | Governed candidate refresh; candidate evidence is not trusted by default. |
| `web_candidate_recrawl_30d` | CKB scheduler every 30 days | `/ckb-refresh web-candidates-recrawl` | Recrawl already governed web candidates. |
| `weekly_full_rebuild` | CKB scheduler every 7 days | `/ckb-refresh rebuild` | Rebuild active/candidate indexes from current store. |
