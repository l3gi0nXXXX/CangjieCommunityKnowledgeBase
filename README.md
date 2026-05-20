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
The `schema` command also reports the GitCode live official API, auth header
strategy, transport diagnostics, and dry-run/apply acceptance order.

## GitCode Live Sync Scope

CKB GitCode live sync supports public repositories only. Public repository
enumeration and public source reads are the only repository acquisition path in
this implementation. Repositories whose visibility is private, internal, or
unknown are out of scope and must not enter knowledge acquisition, indexing, or
trusted evidence.

Do not add or document any repository-visibility setting that expands live sync
beyond public repositories, or any alternate bypass for private/internal
repository acquisition. Historical notes about future private-repository
support are analysis only and are not part of the implemented live sync
contract.

For live GitCode acceptance of public repositories, create only ignored local
files:

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

`tokenFile` must contain exactly one GitCode PAT line. Do not include `token=`,
`Bearer`, `PRIVATE-TOKEN`, quotes, comments, or any other prefix. Run schema and
doctor/status first, then anonymous dry-run, credentialed dry-run only if
needed, limited apply, rebuild-index, and final status/evidence checks. Never
commit `ckb-live.conf`, `tokenFile`, or terminal output containing credentials.

Live HTTP sync uses the native Cangjie HTTP/TLS transport by default. `network.proxy`
accepts an HTTP proxy such as `http://127.0.0.1:7897`; HTTPS targets use an HTTP
CONNECT tunnel through that proxy. `network.envProxyEnabled=true` allows the
transport to honor process proxy environment variables, while `network.noProxy`
lists comma-separated hosts or suffixes that must bypass proxy routing.
`network.insecureSkipTlsVerify` defaults to `false` and should stay disabled for
production acceptance unless a controlled diagnostic explicitly requires it.
Human-facing doctor and dry-run output redacts tokens, cookies, proxy passwords,
and local absolute paths.

For TLS or route diagnostics, use the read-only native HTTP smoke command
before running live sync:

```bash
cjpm run --skip-build --run-args "native-http-smoke https://api.gitcode.com/api/v5/orgs/cangjie/repos?type=public&page=1&per_page=1"
```

The smoke command does not resolve GitCode credentials, does not read
`tokenFile` or cookie files, and does not write raw, candidate, or active
knowledge data. It only performs a native GET for an allowlist URL and reports
route mode, target host, TLS verify mode, HTTP status, transport class, and a
redacted diagnostic.

TLS failures are diagnosed by the native transport. DNS failures such as
`Failed to resolve address` are reported as `dns`; certificate trust failures
such as `unknown CA` or `certificate verify failed` are reported as
`tls_unknown_ca`; hostname and expired-certificate failures have separate TLS
diagnostic classes. If Metis-aligned direct HTTPS still fails after the native
transport no longer installs a direct socket connector, the next production fix
is CA trust-store discovery or explicit CA bundle support. Do not promote
`network.insecureSkipTlsVerify=true` as an operating solution.

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

Operational integration with Metis and GitCodeMonitor is documented in
`docs/metis-gitcodemonitor-integration.md`. Manual production acceptance is
tracked with `docs/manual-acceptance-checklist.md`.

## Contribution Rules

Keep knowledge synchronization, storage, indexing, and evidence-pack lifecycle
inside this project. Do not generate final GitCode replies here; Metis owns
reply generation. Do not scan GitCode monitor cursors or write GitCode comments
here; GitCodeMonitor owns that lifecycle.
