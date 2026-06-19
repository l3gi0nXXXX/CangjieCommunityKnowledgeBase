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
export CANGJIE_HOME=/path/to/cangjie
source "${CANGJIE_HOME}/envsetup.sh"
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
cjpm run --run-args "source_analysis repo=cangjie/stdx ref=main path=src/http/client.cj query=compile_error"
cjpm run --run-args "service-once health"
cjpm run --run-args "backup target/ckb-active-copy"
```

The `doctor` command reports logical storage paths, source-scope coverage,
index counts, and scheduler state. It does not expose local mirror paths.
The `schema` command also reports the GitCode live official API, auth header
strategy, transport diagnostics, and dry-run/apply acceptance order.

`source_analysis` is an explicit on-demand capability for issue/PR debugging
and review workflows. It accepts `repo`, `ref`, `query`, `issueUrl`, `prUrl`,
`changedFiles`, `candidatePaths`, `allowCloneFallback`, `maxFiles`, `maxBytes`,
and `timeoutMillis`. The current SRC-0/SRC-1/SRC-2 implementation reads source
through API raw first and contents fallback second; it reports degraded status
instead of cloning when fallback is disabled or unavailable.

## MCP Access

CKB exposes two MCP transports for read-only Cangjie knowledge access.

`mcp-stdio` is for local MCP clients that launch CKB as a child process:

```bash
cjpm run --skip-build --run-args "--store $(pwd)/ckb-data mcp-stdio"
```

It writes only JSON-RPC responses to stdout. JSON-RPC notifications such as
`notifications/initialized` and `notifications/cancelled` produce no stdout
line.

`service-http` exposes MCP Streamable HTTP on `/mcp`:

```bash
cjpm run --skip-build --run-args "--store $(pwd)/ckb-data service-http"
```

The first-stage Streamable HTTP contract is:

- `POST /mcp` accepts one JSON-RPC object with
  `Accept: application/json, text/event-stream` and
  `Content-Type: application/json`.
- `initialize` must request `protocolVersion=2025-06-18`; CKB returns
  `Mcp-Session-Id`.
- Follow-up POST/GET/DELETE requests must carry `Mcp-Session-Id` and
  `MCP-Protocol-Version: 2025-06-18`.
- JSON-RPC requests return `200 application/json`.
- JSON-RPC notifications/responses return `202` with an empty body.
- `GET /mcp` returns `text/event-stream` and starts with
  `: ckb-mcp-ready`.

MCP exposes only the Cangjie read-only tools/resources/prompts. It does not
expose admin refresh, update, repository sync, event ingest, or code execution
tools.

## Local Knowledge Store

CKB stores knowledge on the local filesystem. For this workspace, the formal
persistent store is:

```text
<CKB_PROJECT_ROOT>/ckb-data
```

Use this same `--store` path for `sync-live`, `rebuild-index`, `query`,
`evidence`, `source_analysis`, `service`, `backup`, and `restore`:

```bash
export CKB_PROJECT_ROOT="$(pwd)"
cjpm run --skip-build --run-args "--config ckb-live.conf --store ${CKB_PROJECT_ROOT}/ckb-data sync-live --apply --max-repos 5 --max-files-per-repo 2 --max-items 30"
cjpm run --skip-build --run-args "--config ckb-live.conf --store ${CKB_PROJECT_ROOT}/ckb-data rebuild-index"
cjpm run --skip-build --run-args "--config ckb-live.conf --store ${CKB_PROJECT_ROOT}/ckb-data evidence README"
```

Do not use `target/ckb-data` as a formal persistent knowledge store.
`target/` is a build artifact directory, and `cjpm clean` removes it. The
project `data/` directory is only the committed logical layout skeleton; live
knowledge records belong under the configured `--store`.

The physical store layout is:

```text
raw/
normalized/
metadata/
index/
derived/
cache/
```

Doctor and status output intentionally show logical `data/...` paths instead
of absolute local host paths.

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
network.caFile=/etc/ssl/cert.pem
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
`network.caFile` is optional and maps a user-provided CA bundle to
`SSL_CERT_FILE` for the native TLS child process; on macOS `/etc/ssl/cert.pem`
matches the CA file reported by `curl -v`. Human-facing doctor and dry-run
output redacts tokens, cookies, proxy passwords, and local absolute paths.
GitCode source file fetches use the official source API in priority order:
raw file (`/repos/:owner/:repo/raw/:path?ref=:ref`) first, then
contents/base64 (`/repos/:owner/:repo/contents/:path?ref=:ref`) as the
fallback contract, then degraded reporting. Raw responses are accepted only
for text/Markdown or UTF-8 octet-stream bodies within the source file byte
limit reported by dry-run output.

On macOS, native network commands bootstrap their own TLS runtime before the
request path runs. The bootstrap follows the Metis Gateway launch pattern by
restarting the command with OpenSSL 3 and Cangjie/stdx dynamic library paths in
`DYLD_LIBRARY_PATH`. It does not generate CA bundles or repair certificate trust
stores. When `network.caFile` is configured, the bootstrap passes that explicit
file to OpenSSL through `SSL_CERT_FILE`.

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
diagnostic classes. Missing OpenSSL runtime functions are reported as
`tls_runtime`. A `tls_unknown_ca` result is diagnostic only; CKB does not
automatically repair the host CA trust configuration. Do not promote
`network.insecureSkipTlsVerify=true` as an operating solution.

## Production Embedding and Vector DB

The default runtime remains deterministic embedding plus the local-file vector
store. Production semantic retrieval is configured explicitly with Ollama
`bge-m3:latest` and Qdrant:

```text
embedding.provider=ollama
embedding.model=bge-m3:latest
embedding.endpoint=http://127.0.0.1:11434/api/embed
embedding.dimensions=1024
embedding.batchSize=16
embedding.timeoutMillis=30000
embedding.retryCount=2
embedding.allowPrivateEndpoint=true

vector.backend=qdrant
vector.endpoint=http://127.0.0.1:6333
vector.activeCollection=ckb_active
vector.candidateCollection=ckb_candidate
vector.dimensions=1024
vector.distance=Cosine
vector.timeoutMillis=10000
vector.retryCount=2
vector.apiKeyFile=
vector.allowPrivateEndpoint=true
```

`embedding.allowPrivateEndpoint` and `vector.allowPrivateEndpoint` are scoped to
the embedding/vector adapters. They do not widen GitCode or website source
fetch private-network access. Runtime summaries report endpoint and api-key
presence only; token contents and local paths must stay redacted.

The runtime factory now has explicit `embedding.provider=ollama` and
`vector.backend=qdrant` branches backed by `OllamaEmbeddingProvider` and
`QdrantVectorStore`. Production configs must use these adapters directly rather
than silently falling back to deterministic/local behavior.

Generated CKB data, Qdrant storage, `ckb-live.conf`, token files, and local
acceptance logs must remain ignored local files. Do not bypass `.gitignore` or
commit anything under local `ckb-data/` directories.

Detailed production semantic retrieval runbook:
`docs/production-embedding-vector-db.md`.

## Service Protocol

CKB can run as a long-lived stdio service:

```bash
cjpm run --run-args "--config ckb-live.conf --store ${CKB_PROJECT_ROOT}/ckb-data service"
```

The service prints one key-value response per command. Supported commands are:
`health`, `status`, `metrics`, `query <text>`, `evidence <text>`,
`source_analysis repo=<owner/repo> ref=<ref> path=<path> query=<text>`, `sync`,
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
- `cangjie_source_analysis`
- `cangjie_knowledge_status`

Web candidate evidence is always marked `requiresReview=true` by default.

Source analysis is disabled by default. When `sourceAnalysis.enabled=true`, CKB
may shallow-clone public GitCode repositories into
`${TMPDIR:-/tmp}/ckb-source-analysis` or an absolute configured
`sourceAnalysis.workspaceRoot`, select only requested source/text files, return
repository-relative citations and body hashes, and clean temporary run
directories by default. Private, internal, unknown visibility, non-GitCode clone
hosts, binary files, build outputs, and absolute checkout paths are excluded.

Operational integration with Metis and GitCodeMonitor is documented in
`docs/metis-gitcodemonitor-integration.md`. Manual production acceptance is
tracked with `docs/manual-acceptance-checklist.md`.

## Contribution Rules

Keep knowledge synchronization, storage, indexing, and evidence-pack lifecycle
inside this project. Do not generate final GitCode replies here; Metis owns
reply generation. Do not scan GitCode monitor cursors or write GitCode comments
here; GitCodeMonitor owns that lifecycle.
