# CKB Manual Acceptance Checklist

Use this checklist for production readiness acceptance. Record evidence in the
release ticket or run log, not in committed credential files.

## Preflight

- [ ] CKB, Metis, and GitCodeMonitor are running from separate repositories or
  worktrees.
- [ ] `.gitignore` ignores local credential files such as `tokenFile` and live
  runtime configs, and ignores the formal local knowledge store path when that
  store is inside a parent workspace.
- [ ] No real credential value is committed in docs, source, tests, or fixtures.
- [ ] Formal CKB knowledge storage uses
  `/Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase/ckb-data`, not `target/ckb-data`.
- [ ] Every production-like command uses the same explicit
  `--store /Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase/ckb-data` argument.
- [ ] `target/ckb-data` is treated as disposable only. `cjpm clean` removes
  files under `target/`, so it must not hold the formal active knowledge store.
- [ ] The committed `data/` directory is only a logical layout skeleton and does
  not contain live production knowledge records.
- [ ] `cjpm run --run-args schema` lists health, status, query, evidence, sync,
  rebuild, GitCode official API, auth header strategy, transport diagnostics,
  public-only repository scope, and dry-run/apply acceptance order.
- [ ] `cjpm run --run-args status` reports logical data paths and redacted
  runtime configuration only.
- [ ] Local `ckb-live.conf` is ignored and uses the repaired GitCode API
  configuration:

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
network.proxy=
network.envProxyEnabled=false
network.noProxy=
network.insecureSkipTlsVerify=false
network.caFile=/etc/ssl/cert.pem
```

- [ ] Live GitCode sync is limited to public repositories. Private, internal,
  or unknown-visibility repositories are rejected before knowledge acquisition.
- [ ] Local configs, scripts, runbooks, and command examples do not include any
  repository-visibility mode that expands sync beyond public repositories, or
  any bypass for non-public repository acquisition.
- [ ] Local `tokenFile` contains exactly one GitCode PAT line. Do not include
  `token=`, `Bearer`, `PRIVATE-TOKEN`, quotes, comments, or any other prefix.
- [ ] `doctor` reports `transport=native`, `network.proxy`, `network.envProxy`,
  `network.noProxy`, `network.insecureSkipTlsVerify`, `network.timeoutMillis`,
  and `network.retryCount` with sensitive values redacted.
- [ ] Source analysis is off by default: `doctor`, `status`, or schema output
  reports `sourceAnalysis.enabled=false` unless an ignored local config
  explicitly enables it.

## Embedding and Vector DB Preflight

- [ ] The ignored local config keeps deterministic/local defaults unless a
  production semantic run is intended.
- [ ] Production semantic config uses `embedding.provider=ollama`,
  `embedding.model=bge-m3:latest`, `embedding.dimensions=1024`,
  `embedding.endpoint=http://127.0.0.1:11434/api/embed`, and
  `embedding.allowPrivateEndpoint=true`.
- [ ] Production vector config uses `vector.backend=qdrant`,
  `vector.endpoint=http://127.0.0.1:6333`,
  `vector.activeCollection=ckb_active`,
  `vector.candidateCollection=ckb_candidate`,
  `vector.dimensions=1024`, `vector.distance=Cosine`, and
  `vector.allowPrivateEndpoint=true`.
- [ ] `doctor` or `status` reports `embedding.endpoint=present`,
  `embedding.allowPrivateEndpoint=true`, `vector.endpoint=present`,
  `vector.dimensions=1024`, `vector.distance=Cosine`, and api-key presence
  only. It must not print token contents, `vector.apiKeyFile` paths, or local
  `ckb-data` paths.
- [ ] If `embedding.allowPrivateEndpoint=false`, an Ollama loopback endpoint
  reports a degraded private-endpoint diagnostic before any network call.
- [ ] If `vector.allowPrivateEndpoint=false`, a Qdrant loopback endpoint
  reports a degraded private-endpoint diagnostic before any network call.
- [ ] `embedding.provider=ollama` and `vector.backend=qdrant` route to the real
  Ollama and Qdrant adapters. They must not silently fall back to
  deterministic/local behavior.
- [ ] Qdrant storage, `ckb-live.conf`, token files, api-key files, and
  acceptance logs stay ignored local files. Do not bypass `.gitignore`.

## Real Source Sync

- [ ] On macOS, no manual TLS environment export is required for CKB network
  commands. The command relaunches itself once with the Metis Gateway-style
  OpenSSL 3 `DYLD_LIBRARY_PATH` handling.
- [ ] If `curl -v https://cangjie-lang.cn/` reports `CAfile: /etc/ssl/cert.pem`,
  set `network.caFile=/etc/ssl/cert.pem` in the ignored local config so CKB
  passes the same CA bundle to native OpenSSL.
- [ ] If the native transport still reports `transportClass=tls_runtime`, the
  bootstrap could not make OpenSSL 3 visible to the child process. If it
  reports `transportClass=tls_unknown_ca`, OpenSSL is loaded but the remote
  certificate chain is not trusted by the configured CA file or environment;
  CKB reports this diagnostic and does not automatically repair CA trust.
- [ ] Native TLS bootstrap does not generate `/tmp/ckb-system-roots.pem` and
  does not automatically copy certificates into a CA bundle.
- [ ] Before full live sync, run the read-only native HTTP smoke command
  against a public allowlist URL:

```bash
cjpm run --skip-build --run-args "native-http-smoke https://api.gitcode.com/api/v5/orgs/cangjie/repos?type=public&page=1&per_page=1"
```

- [ ] Smoke output includes `native-http-smoke`, `route=`, `targetHost=`,
  `tlsVerifyMode=`, `httpStatus=`, `transportClass=`, and a redacted
  `transportDiagnostic=`.
- [ ] Smoke output reports `rawWritten=false`, `candidateWritten=false`, and
  `activePromoted=false`; no raw/candidate/active knowledge files are created
  by the smoke command.
- [ ] Smoke does not read or require `tokenFile`, cookie files, or GitCode
  credentials. It must not print token, cookie, proxy auth, or absolute local
  path values even on failure.
- [ ] Smoke blocks non-HTTP URLs and private-network URLs before any native
  GET is attempted.
- [ ] Production live sync uses the Cangjie native HTTP/TLS executor. Dry-run
  output must not contain `curl launch failed`, `curlExitCode=-1`, or any
  other diagnostic that proves the default path still shells out to `curl`.
- [ ] GitCode source file dry-run requests report `sourceVariant=raw` for the
  default `/raw/:path?ref=:ref` endpoint; `/contents/:path?ref=:ref` remains
  the fallback contract, not the default source path.
- [ ] Native HTTP dry-run is started with the ignored local config file:

```bash
cjpm run --skip-build --run-args "--config ckb-live.conf --store /Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase/ckb-data sync-live --dry-run --max-repos 5 --max-files-per-repo 2 --max-items 30"
```

- [ ] The native HTTP dry-run reports `network=enabled`, reaches the GitCode
  organization repository-list endpoint, and prints `repoDiscovery` with
  `discovered` and `public` counts greater than zero when the upstream API is
  reachable.
- [ ] If the upstream API, TLS, DNS, proxy, or timeout path fails, the output
  reports a native transport class such as `dns`, `tls_unknown_ca`,
  `tls_hostname_mismatch`, `tls_expired_certificate`,
  `tls_runtime`, `tls_handshake_failed`, `proxy`, `connection_refused`, or
  `timeout`; it must not report `curl launch failed` as the primary diagnostic.
- [ ] A DNS-only failure such as `Failed to resolve address example.invalid`
  is reported as `transportClass=dns`, not `unknown`.
- [ ] A certificate trust failure such as `unknown CA` or `certificate verify
  failed` is reported as `transportClass=tls_unknown_ca` or an equivalent
  visible TLS trust diagnostic; it is not automatically repaired by CKB.
- [ ] If direct HTTPS still fails after the CKB native transport is aligned to
  the Metis Feishu/provider direct HTTPS path, the next investigation is
  environment-side CA trust-store configuration or a separately designed CA
  support feature. Do not use `network.insecureSkipTlsVerify=true` as a
  production workaround.
- [ ] If an HTTP proxy is configured for live acceptance, HTTPS GitCode and
  documentation requests must route through native HTTP CONNECT before stdx
  TLS handles the final HTTPS request. Proxy credentials must be redacted in
  all doctor, dry-run, and error outputs.
- [ ] Anonymous dry-run reaches GitCode, the Cangjie official website, and the
  Cangjie documentation site, or reports a classified upstream failure.
- [ ] Dry-run output never reports `curl launch failed` or `curlExitCode` on
  the default live path. Transport failures are reported with
  `transportClass` and `transportDiagnostic`.
- [ ] GitCode dry-run output confirms public repository scope and does not
  schedule private, internal, or unknown-visibility repositories for fetch,
  normalization, indexing, or trusted evidence.
- [ ] If GitCode requires authentication, CKB uses an ignored local token file
  and reports only credential presence plus `authHeader=private-token`.
- [ ] GitCode source fetch uses `sourceVariant=raw` first. If raw returns a
  source-unavailable HTTP failure, dry-run shows `contentsFallback=attempted`
  and the follow-up source summary reports `sourceVariant=contents`.
- [ ] Contents fallback accepts only `type=file` with `encoding=base64`, rejects
  malformed or path-mismatched payloads, and keeps repo/ref/path plus
  `repoVisibility=public` on accepted source records.
- [ ] Live acceptance order is schema, doctor/status, anonymous dry-run,
  credentialed dry-run only if needed, limited apply, rebuild-index, then
  status/evidence verification.
- [ ] Small apply run is limited by `--max-repos`, `--max-files-per-repo`, and
  `--max-items`.
- [ ] After limited apply and rebuild-index, `evidence README` or
  `source_search README` can return a GitCode source file citation when a source
  file was fetched successfully.
- [ ] Raw, normalized, metadata, index, derived, and cache layers are written
  only under the CKB store.
- [ ] Issue and PR history are ingested as community evidence, not trusted
  official source evidence.
- [ ] Governed web candidates remain `requiresReview=true`.
- [ ] Ordinary `sync-live --dry-run` does not create or retain any checkout
  under `${TMPDIR:-/tmp}/ckb-source-analysis` or the configured
  `sourceAnalysis.workspaceRoot`.

## Source Analysis

- [ ] `cjpm run --run-args schema` lists `cangjie.source_analysis` and
  `POST /source_analysis`.
- [ ] With `sourceAnalysis.enabled=false`, a source-analysis request returns a
  disabled diagnostic and performs no clone.
- [ ] With an ignored local config that sets `sourceAnalysis.enabled=true`,
  `sourceAnalysis.workspaceRoot` is absolute, not the project root, and not a
  path containing `..` escape segments.
- [ ] A bug-oriented fake or public repository request returns an analysis pack
  with selected files, `citations`, `bodyHash`, `truncated` when budgets apply,
  and `cleanupStatus`.
- [ ] Private, internal, or unknown visibility fixture metadata returns a
  non-public diagnostic and the clone executor is not called.
- [ ] Clone URLs are accepted only for the GitCode public host allowlist.
- [ ] Successful source analysis removes the run directory; failure also removes
  it unless `retainFailedWorkspace=true` is set for an operator diagnostic run.
- [ ] Retained failure output shows only a redacted workspace status, never the
  absolute checkout path.
- [ ] Binary files, `.git`, `target`, `build`, and `vendor` paths are absent
  from the returned pack.
- [ ] Timeout and missing-git failures return visible diagnostics such as
  `clone_timeout` or `git_unavailable` without blocking the service.

## Service Health and Status

- [ ] Health/status returns `activeKnowledgeVersion`.
- [ ] Status includes storage counts, active state source, restore diagnostic,
  and index manifest.
- [ ] Status does not expose absolute local mirror paths.
- [ ] Metis receives and logs the CKB knowledge version for each evidence call.
- [ ] GitCodeMonitor direct CKB access is limited to health/status/diagnostic
  sync workflows.

## Query and Evidence

- [ ] Query returns ranked evidence with citations or source URLs.
- [ ] Evidence pack includes doc, source, website, community, or governed
  candidate sections as applicable.
- [ ] Metis does not use evidence rows without citation/source URL for final
  user-visible claims.
- [ ] Candidate evidence is either reviewed before use or clearly excluded from
  trusted answer generation.
- [ ] Output contains no token values, `Authorization` header values, `Cookie`
  header values, or private paths.

## Production Embedding and Vector DB

- [ ] Baseline mode explicitly reports `embedding.provider=deterministic` and
  `vector.backend=local-file`; this mode is accepted only for functional and
  integration verification.
- [ ] Production semantic retrieval is not declared complete while CKB still
  relies only on deterministic embeddings and local-file vectors.
- [ ] A real embedding provider is selected, with model, dimensions, endpoint,
  token source, timeout, retry count, batch size, and redaction behavior
  documented.
- [ ] A real vector backend is selected, such as Qdrant, Milvus, Chroma, or
  pgvector. Qdrant is the preferred initial low-operations candidate unless a
  different backend is explicitly chosen.
- [ ] Local Ollama `bge-m3:latest` from `baai/bge-m3` is reachable at
  `http://127.0.0.1:11434/api/embed` and returns 1024-dimensional embeddings.
- [ ] Local Qdrant single-node container `ckb-qdrant` is reachable at
  `http://127.0.0.1:6333`, with persistent storage under
  `/Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase/ckb-data/qdrant/storage`.
- [ ] Qdrant smoke verification can create, upsert into, inspect, and delete a
  1024-dimensional temporary collection without leaving test collections behind.
- [ ] Active and candidate vector collections are isolated by knowledge version
  or collection name, and failed candidate vector writes do not replace active
  retrieval.
- [ ] Rebuild, backup, restore, health/status, and rollback behavior are tested
  against the selected vector backend.
- [ ] Evidence/query acceptance proves semantic retrieval quality against
  Cangjie source, documentation, website, and GitCode community records, not
  only keyword-like deterministic vector behavior.

## Rebuild and Version Safety

- [ ] Rebuild creates a candidate version before active promotion.
- [ ] Successful rebuild updates `activeKnowledgeVersion`.
- [ ] Failed validation leaves the previous active version queryable.
- [ ] Evidence and graph context report the same active knowledge version after
  restore.

## Backup and Restore

- [ ] Store backup captures raw, normalized, metadata, index, derived, and cache
  layers.
- [ ] Restore into a clean store preserves active index and metadata agreement.
- [ ] Malformed or missing active snapshot falls back safely and reports a
  restore diagnostic.
- [ ] Rollback procedure is tested without changing Metis or GitCodeMonitor
  repository contents.

## Long-Running Operation

- [ ] Scheduler windows match expected sync intervals for active items, active
  repos, website/docs probes, candidate recrawls, and weekly rebuilds.
- [ ] Rate limits and timeouts are classified and retried with backoff.
- [ ] Repeated dry-run/apply cycles do not leak credentials in logs.
- [ ] Disk growth is monitored for raw and normalized layers.
- [ ] Stop order is documented: GitCodeMonitor, Metis, then CKB sync/service.

## Exception Recovery

- [ ] Network disabled reports `ckb.network_disabled` or equivalent diagnostic.
- [ ] `network.enabled=false` prevents any HTTP executor call and does not read
  GitCode token or cookie files.
- [ ] Authentication failure reports `ckb.auth_degraded` without credential
  content.
- [ ] Rate limiting reports `ckb.rate_limited` and preserves retry-after when
  available.
- [ ] Source unavailable and timeout cases are visible in logs.
- [ ] Candidate validation failure does not promote an active version.

## Native HTTP Automated Test Coverage

- [ ] `test/src/ckb_native_http_transport_test.cj` passes together with the
  baseline tests.
- [ ] Status mapping tests prove 401/403, 404, 429, 5xx, and timeout responses
  still map to the same CKB source-fetch statuses after the native executor
  replaces the curl executor.
- [ ] Retry tests prove retry decisions do not depend on a curl exit code.
- [ ] Header tests prove GitCode token headers are sent only to GitCode API
  requests and are never sent to official website or documentation requests.
- [ ] Redaction tests prove token, cookie, query-token, proxy credential, and
  local absolute path values are not exposed.
- [ ] Fake live dry-run tests prove private, internal, and unknown-visibility
  repositories are excluded before any repo-scoped source, issue, PR, or
  comment fetch is planned.
- [ ] After the native transport worker lands callable pure helpers, add or
  enable focused tests for proxy route resolution, `no_proxy`, CONNECT request
  construction, URL safety, header parsing, and native exception
  classification.
