# CKB Manual Acceptance Checklist

Use this checklist for production readiness acceptance. Record evidence in the
release ticket or run log, not in committed credential files.

## Preflight

- [ ] CKB, Metis, and GitCodeMonitor are running from separate repositories or
  worktrees.
- [ ] `.gitignore` ignores local credential files such as `tokenFile` and live
  runtime configs.
- [ ] No real credential value is committed in docs, source, tests, or fixtures.
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

## Real Source Sync

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
- [ ] Live acceptance order is schema, doctor/status, anonymous dry-run,
  credentialed dry-run only if needed, limited apply, rebuild-index, then
  status/evidence verification.
- [ ] Small apply run is limited by `--max-repos`, `--max-files-per-repo`, and
  `--max-items`.
- [ ] Raw, normalized, metadata, index, derived, and cache layers are written
  only under the CKB store.
- [ ] Issue and PR history are ingested as community evidence, not trusted
  official source evidence.
- [ ] Governed web candidates remain `requiresReview=true`.

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
- [ ] Authentication failure reports `ckb.auth_degraded` without credential
  content.
- [ ] Rate limiting reports `ckb.rate_limited` and preserves retry-after when
  available.
- [ ] Source unavailable and timeout cases are visible in logs.
- [ ] Candidate validation failure does not promote an active version.
