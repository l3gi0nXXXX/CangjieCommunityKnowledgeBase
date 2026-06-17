# CangjieEval v0

CangjieEval v0 is the minimum offline evaluation loop for CKB Cangjie language knowledge service work. The first stage is parse-only: it defines the dataset contract and summary shape, but does not call a model, open the network, or execute generated code.

## Dataset

The manifest lives at `test/cangjie_eval/manifest.jsonl`. Each line is one JSON object with these fields:

- `id`: stable case id.
- `category`: one of `compile`, `unit`, `repair`, `api_hallucination`.
- `targetVersion`: Cangjie target version, initially `1.0.0`.
- `prompt`: model-facing task prompt.
- `entryPoint`: relative fixture directory under `test/cangjie_eval/fixtures`.
- `testCommand`: command a future runner may execute inside an isolated fixture copy.
- `expectedKnowledgeTags`: offline knowledge tags expected to be retrieved or cited.

The v0 manifest contains 24 offline cases, six per category. Fixtures are intentionally minimal templates, not full generated answers.

## Metrics

The parse-only harness renders these summary fields with initial values of `0` until an executor is added:

- `compilePassRate`: build-only cases that compile.
- `unitPassRate`: unit-test cases that pass.
- `repairPassRate`: broken input cases repaired into a passing state.
- `apiHallucinationRate`: cases where output invents unsupported packages, members, or APIs.

The summary also reports category counts: `compileCases`, `unitCases`, `repairCases`, and `apiHallucinationCases`.

## A/B Groups

The manifest IDs are split by odd/even suffix:

- Group A: odd-numbered case IDs, intended for baseline CKB retrieval.
- Group B: even-numbered case IDs, intended for changed retrieval or prompt policy.

Both groups keep equal category coverage. A future runner should compare only cases with the same category and similar knowledge tags.

## Runtime

The first-stage implementation only parses manifest lines and renders summaries. Future execution must run from disposable copies of fixture directories and use only project-local files. The intended command environment is the repository Cangjie SDK setup used by CI:

```bash
source "$CANGJIE_HOME/envsetup.sh"
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/openssl@3/lib:$DYLD_LIBRARY_PATH"
```

The current parse-only CLI entry is:

```bash
cjpm run --skip-build --run-args "cangjie-eval-summary test/cangjie_eval/manifest.jsonl"
```

Expected v0 output includes `executionMode=parse_only_offline`,
`totalCases=24`, and `invalidLines=0`. This command reads the manifest and
renders category counts only; it does not execute any manifest `testCommand`.

The manifest and fixtures must not contain real user paths, real access tokens, real proxy credentials, or real service endpoints.

## Network Policy

CangjieEval v0 is offline. The harness must not:

- call a model;
- fetch documents from the internet;
- clone repositories;
- run package install commands;
- read user files outside the fixture tree;
- log or persist secrets.

Manifest parsing rejects lines containing top-level secret fields such as `token`, `accessToken`, `apiKey`, `password`, or `secret`, and rejects `/Users/` paths.
