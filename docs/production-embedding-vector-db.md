# Production Embedding and Vector DB

This runbook covers the CKB runtime wiring for local Ollama `bge-m3:latest`
embeddings and Qdrant vector storage. It does not describe Metis or
GitCodeMonitor changes.

## Runtime Config

Use an ignored local config file such as `ckb-live.conf`:

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

The private-endpoint switches are adapter scoped. They allow local Ollama and
Qdrant endpoints without changing GitCode or website source-fetch private
network policy.

## Acceptance Order

1. Confirm Ollama is running and `bge-m3:latest` is installed.
2. Confirm Qdrant is running and its HTTP endpoint returns a version response.
3. Run `cjpm build -i`.
4. Run the test package from `test/` with `cjpm test`.
5. Run `cjpm run --skip-build --run-args "--config ckb-live.conf doctor"`.
6. Run limited source sync, then `rebuild-index`, then `evidence <query>`.
7. Check that active and candidate collection names remain distinct.

Until the concrete Ollama and Qdrant adapters are merged, the factory branches
are expected to report pending degraded diagnostics. Treat a silent fallback to
deterministic/local under production config as a failure.

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
- `ollama_embedding_adapter_pending` or `qdrant_vector_adapter_pending`: runtime
  config and factory routing are present, but the core HTTP adapter has not
  been linked in this worker branch.

## Repository Hygiene

Do not commit generated data, Qdrant storage, local configs, token files,
api-key files, or acceptance logs. Keep production data under ignored CKB data
directories and never work around `.gitignore`.
