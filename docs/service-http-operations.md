# CKB Service HTTP Operations

This runbook starts CKB with a production-scale knowledge snapshot and
distinguishes heap configuration failures from HTTP bind failures.

## Runtime prerequisites

Set the Cangjie SDK, native OpenSSL lookup path, and heap before starting the
process:

```bash
source <CANGJIE_SDK_ROOT>/envsetup.sh
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/openssl@3/lib:$DYLD_LIBRARY_PATH"
export cjHeapSize=4GB
```

`cjHeapSize` is a Cangjie runtime environment variable. It must be present
before the process starts; it is intentionally not stored in `ckb-live.conf`.
The Cangjie runtime otherwise defaults to a 256MB heap on machines with more
than 1GB of physical memory. CKB uses 4096MiB as the production service safety
gate because a production snapshot must load with headroom for retrieval and
HTTP traffic. This is not a claim that every smaller snapshot needs 4GB.

## Start and verify

From the repository root:

```bash
cjpm build -i
export CKB_BIN="$PWD/target/release/bin/main"
"$CKB_BIN" --config <CKB_CONFIG> --store <CKB_STORE> service-http
```

In another terminal:

```bash
curl --fail --silent --show-error http://127.0.0.1:18890/v1/health
```

Pass criteria:

- startup prints `service-http protocol=ckb-http-v1`;
- the health request returns HTTP 200;
- repeated health requests keep the same CKB PID;
- the command does not modify the configured store merely to satisfy the heap
  gate.

## Heap diagnostics

Service-style commands reject unsafe runtime settings before reading the
active snapshot:

| Error code | Meaning | Action |
|---|---|---|
| `ckb.service_heap_not_configured` | `cjHeapSize` is absent | `export cjHeapSize=4GB` and restart |
| `ckb.service_heap_invalid` | the value cannot be parsed | use `4GB` or `4096MB` |
| `ckb.service_heap_too_small` | parsed heap is below 4096MiB | raise it to at least `4GB` |

Diagnostics do not echo the invalid input, configuration contents, tokens, or
local private paths.

## Port and transport diagnostics

The default bind is `127.0.0.1:18890`. If the port is already occupied, CKB
returns `ckb.http_service_failed`; this is an HTTP bind failure, not an OOM.
Inspect the process that owns the port or choose another service port in the
test configuration. Do not alter the knowledge snapshot to address a bind
failure.

OpenSSL loader errors are separate from heap and bind failures. Ensure
`DYLD_LIBRARY_PATH` contains the Homebrew OpenSSL 3 library directory before
starting CKB.
