# Production Embedding and Vector DB Runbook

This runbook records the local production-grade embedding/vector stack selected
for CKB acceptance in this workspace.

## Persistent Store

The formal CKB knowledge store is local filesystem storage at:

```text
<CKB_PROJECT_ROOT>/ckb-data
```

This directory is inside the CKB project but must remain ignored by git. Use the
same `--store` value for `sync-live`, `rebuild-index`, `query`, `evidence`,
`source_analysis`, `service`, `backup`, and `restore`.

Do not use `target/ckb-data` as formal storage. `target/` is disposable build
output and `cjpm clean` removes it.

## Local Embedding Model

The local embedding model is served by Ollama:

```text
provider=ollama
endpoint=http://127.0.0.1:11434
model=bge-m3:latest
source model=baai/bge-m3
dimensions=1024
```

Verified model discovery:

```bash
curl -sS http://127.0.0.1:11434/api/tags
```

Verified embedding call, preferred batch-capable API:

```bash
curl -sS http://127.0.0.1:11434/api/embed \
  -d '{"model":"bge-m3:latest","input":"仓颉 HttpClient 如何设置超时"}'
```

Expected response shape:

```text
{
  "model": "bge-m3:latest",
  "embeddings": [[... 1024 Float values ...]],
  ...
}
```

CKB production embedding configuration maps to the preferred `/api/embed`
contract:

```text
embedding.provider=ollama
embedding.model=bge-m3:latest
embedding.endpoint=http://127.0.0.1:11434/api/embed
embedding.dimensions=1024
embedding.batchSize=16
embedding.timeoutMillis=30000
embedding.retryCount=2
embedding.allowPrivateEndpoint=true
```

No embedding token is required for the local Ollama endpoint. If a future
remote embedding provider is used, token configuration must use a token file and
must remain redacted in `doctor`, `status`, dry-run, and service output.

## Qdrant Single-Node Deployment

Qdrant is deployed as a local Docker container:

```text
container=ckb-qdrant
image=qdrant/qdrant:latest
http=http://127.0.0.1:6333
grpc=127.0.0.1:6334
storage=<CKB_PROJECT_ROOT>/ckb-data/qdrant/storage
```

Start or recreate the single-node container:

```bash
export CKB_PROJECT_ROOT=/path/to/CangjieCommunityKnowledgeBase
mkdir -p "${CKB_PROJECT_ROOT}/ckb-data/qdrant/storage"

docker run -d \
  --name ckb-qdrant \
  --restart unless-stopped \
  -p 6333:6333 \
  -p 6334:6334 \
  -v "${CKB_PROJECT_ROOT}/ckb-data/qdrant/storage:/qdrant/storage" \
  qdrant/qdrant:latest
```

Check runtime status:

```bash
docker ps --filter name=ckb-qdrant
curl -sS http://127.0.0.1:6333/
curl -sS http://127.0.0.1:6333/collections
```

CKB vector configuration targets Qdrant like this:

```text
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

The active and candidate collections must stay isolated. Candidate rebuild or
sync failures must not overwrite active retrieval.

## CKB Runtime Wiring

The CKB code now includes the production adapter paths:

- `embedding.provider=ollama` maps to `OllamaEmbeddingProvider`.
- `vector.backend=qdrant` maps to `QdrantVectorStore`.
- Both adapters use CKB native HTTP execution and do not shell out to curl.
- Local `127.0.0.1` endpoints require adapter-scoped private endpoint switches;
  they do not widen GitCode/website source-fetch private-network policy.
- Missing config, blocked private endpoints, malformed JSON, HTTP errors,
  timeout, dimension mismatch, and malformed upstream responses return degraded
  or down status instead of throwing through the CLI.

## Acceptance Order

1. Confirm Ollama is running and `bge-m3:latest` is installed.
2. Confirm Qdrant is running and its HTTP endpoint returns a version response.
3. Run `cjpm clean`.
4. Run `cjpm build -i`.
5. Run the test package from `test/` with `cjpm test`.
6. Run `cjpm run --skip-build --run-args "--config ckb-live.conf --store ${CKB_PROJECT_ROOT}/ckb-data doctor"`.
7. Run limited `sync-live --apply`, then `rebuild-index`, then `evidence <query>`.
8. Check that active and candidate collection names remain distinct.

## Troubleshooting

- `embedding_private_endpoint_not_allowed`: set
  `embedding.allowPrivateEndpoint=true` only for the intended local Ollama
  endpoint.
- `vector_private_endpoint_not_allowed`: set
  `vector.allowPrivateEndpoint=true` only for the intended local Qdrant
  endpoint.
- `ollama_embedding_missing_config`: check provider, model, endpoint, and
  dimensions.
- `qdrant_vector_missing_config`: check backend, endpoint, dimensions, and
  distance.
- `ollama_http_*`, `ollama_timeout`, or `ollama_transport_error`: check local
  Ollama health and model availability.
- `qdrant_*_failed`, `collection_missing`, or `dimension_mismatch`: check
  Qdrant health, collection dimensions, and rebuild flow.

## Repository Hygiene

Do not commit generated data, Qdrant storage, local configs, token files,
api-key files, or acceptance logs. Keep production data under ignored CKB data
directories and never work around `.gitignore`.

The phased adapter implementation plan, including source-backed design evidence
and acceptance criteria, is recorded in:

```text
develop_steps/ckb-bge-m3-qdrant-adapter-plan-2026-05-20.md
```
