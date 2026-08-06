# 运行真实 HumanEval 164

> 当前状态：仅完成脚手架后供维护者手工执行。未获得明确授权前，不得运行本手册中的 `run-certify` 命令，不得启动 Student 模型。

正式执行前必须完成 [`freeze-humaneval-authority-delivery.md`](freeze-humaneval-authority-delivery.md)。认证入口只能使用 production `ckb-repro-verify --mode run-certify`；不得用独立 `cangjie-certification-preflight` 加直接 `cangjie-eval-abcde` 绕过 authority/environment/composition 门禁。

目的：在维护者明确授权后，使用冻结输入执行唯一一次 completion-only HumanEval 164 认证。

工作目录：`${CKB_ROOT}` 指向 clean、canonical 的 CKB 仓库根目录。

命令：仅使用本文登记的 production `ckb-repro-verify` 和独立严格 gate。

预期输出：P8 与严格 gate 均输出单个 JSON，且最终结果为 164/164。

通过标准：所有 authority、environment、composition、generation seal、Base 和 Plus 门禁均通过。

失败处理：任一门禁失败立即停止；门禁失败后不得继续 Runner 或发布。

## 验收目标

- 固定 164 个 case，Group D，completion-only，每题恰好一个业务样本。
- production P8 内部先执行 `--generate-only`，成功后再执行 `--evaluate-frozen --test-suites base,plus`。
- 冻结评测阶段不调用模型；生成失败时不得启动评测阶段。
- 最终 base 和 plus 都是 164/164；unresolved、retry、fallback、协议违规、重复和缺失全部为 0。

## 1. 准备冻结输入

```bash
set -euo pipefail
: "${CKB_ROOT:?set repository root}"
: "${CKB_COMPOSITION_MANIFEST:?set frozen runtime composition manifest}"
: "${CKB_WORK_ROOT:?set a new path that does not exist}"
: "${CKB_RUNTIME_ROOT:?set a new path that does not exist}"
: "${CKB_QDRANT_ROOT:?set a new isolated path that does not exist}"
: "${CKB_SOURCE_ROOT:?set a new materialization path that does not exist}"
: "${CKB_CANDIDATE_ROOT:?set frozen candidate root}"
: "${CKB_P0_MANIFEST:?}"
: "${CKB_P1_SCORE_CONTRACT:?}"
: "${CKB_P2_LOGICAL_SNAPSHOT:?}"
: "${CKB_P3_QDRANT_SNAPSHOT:?}"
: "${CKB_P4_BUILD_PROOF:?}"
: "${CKB_P6_ENVIRONMENT_LOCK:?}"
: "${RUN_CANDIDATE_COMMIT:?set exact clean candidate commit}"
: "${CKB_REPRO_PROMPT_INPUT:?set frozen prompt input whose hash matches the environment lock}"
: "${GLM_API_KEY:?set the credential named by glmCredentialEnv in the environment lock}"
: "${CKB_EMBEDDING_TOKEN:?set the credential named by embeddingCredentialEnv in the environment lock}"
: "${CKB_REPRO_QDRANT_IMAGE:?set the frozen image reference whose ID matches qdrantImageDigest}"

cd "$CKB_ROOT"
: "${CANGJIE_SDK_ROOT:?set the Cangjie SDK root}"
source "$CANGJIE_SDK_ROOT/envsetup.sh"
OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
export cjHeapSize=4GB

# The actual-environment probe reads these values; derive identities from the
# frozen environment lock instead of retyping them.
export CKB_REPRO_REPOSITORY_ROOT="$(pwd -P)"
export CKB_ROOT="$CKB_REPRO_REPOSITORY_ROOT"
test "$(git rev-parse --show-toplevel)" = "$CKB_REPRO_REPOSITORY_ROOT"
test -z "$(git status --porcelain)"
export CKB_REPRO_RUN_CRITICAL_MANIFEST="$CKB_REPRO_REPOSITORY_ROOT/reproducibility/manifests/run-critical-files.json"
export CKB_REPRO_PROMPT_INPUT="$(cd "$(dirname "$CKB_REPRO_PROMPT_INPUT")" && pwd -P)/$(basename "$CKB_REPRO_PROMPT_INPUT")"
export CKB_REPRO_COMPOSITION_MANIFEST="$(cd "$(dirname "$CKB_COMPOSITION_MANIFEST")" && pwd -P)/$(basename "$CKB_COMPOSITION_MANIFEST")"
export CKB_COMPOSITION_MANIFEST="$CKB_REPRO_COMPOSITION_MANIFEST"
export CKB_REPRO_CJC_EXECUTABLE="$(cd "$(dirname "$(command -v cjc)")" && pwd -P)/$(basename "$(command -v cjc)")"
export GLM_PROVIDER="$(jq -er '.glmProvider' "$CKB_P6_ENVIRONMENT_LOCK")"
export GLM_BASE_URL="$(jq -er '.glmBaseUrl' "$CKB_P6_ENVIRONMENT_LOCK")"
export GLM_MODEL="$(jq -er '.glmModel' "$CKB_P6_ENVIRONMENT_LOCK")"
export GLM_CREDENTIAL_ENV="$(jq -er '.glmCredentialEnv' "$CKB_P6_ENVIRONMENT_LOCK")"
export EMBEDDING_PROVIDER="$(jq -er '.embeddingProvider' "$CKB_P6_ENVIRONMENT_LOCK")"
export EMBEDDING_MODEL="$(jq -er '.embeddingModel' "$CKB_P6_ENVIRONMENT_LOCK")"
export EMBEDDING_DIMENSION="$(jq -er '.embeddingDimension' "$CKB_P6_ENVIRONMENT_LOCK")"
export EMBEDDING_CREDENTIAL_ENV="$(jq -er '.embeddingCredentialEnv' "$CKB_P6_ENVIRONMENT_LOCK")"
export CKB_REPRO_MCP_COMMAND="$(jq -er '.mcpCommand' "$CKB_P6_ENVIRONMENT_LOCK")"
export CKB_REPRO_MCP_TRANSPORT="$(jq -er '.mcpTransport' "$CKB_P6_ENVIRONMENT_LOCK")"

test "$GLM_CREDENTIAL_ENV" = GLM_API_KEY
test "$EMBEDDING_CREDENTIAL_ENV" = CKB_EMBEDDING_TOKEN
test "$(docker image inspect --format='{{.Id}}' "$CKB_REPRO_QDRANT_IMAGE")" = \
  "$(jq -er '.qdrantImageDigest' "$CKB_P6_ENVIRONMENT_LOCK")"
test "$(shasum -a 256 "$CKB_REPRO_PROMPT_INPUT" | awk '{print "sha256:"$1}')" = \
  "$(jq -er '.promptHash' "$CKB_P6_ENVIRONMENT_LOCK")"
for root in "$CKB_WORK_ROOT" "$CKB_RUNTIME_ROOT" "$CKB_QDRANT_ROOT" "$CKB_SOURCE_ROOT"; do
  test ! -e "$root"
done
test -d "$CKB_CANDIDATE_ROOT"
test -n "$(find "$CKB_CANDIDATE_ROOT" -mindepth 1 -maxdepth 1 -print -quit)"
```

三个 authority 环境变量必须是绝对 canonical 路径：

```bash
: "${CKB_REPRO_AUTHORITY_DELIVERY:?set authority-delivery.json}"
: "${CKB_REPRO_DATASET_MANIFEST:?set frozen 164 authority manifest}"
: "${CKB_REPRO_AUTHORITY_BUNDLE:?set CKBREL01 authority bundle}"
export CKB_REPRO_AUTHORITY_DELIVERY CKB_REPRO_DATASET_MANIFEST \
  CKB_REPRO_AUTHORITY_BUNDLE CKB_REPRO_REPOSITORY_ROOT \
  CKB_REPRO_RUN_CRITICAL_MANIFEST CKB_REPRO_PROMPT_INPUT \
  CKB_REPRO_COMPOSITION_MANIFEST GLM_PROVIDER GLM_BASE_URL GLM_MODEL \
  CKB_REPRO_CJC_EXECUTABLE CKB_REPRO_QDRANT_IMAGE \
  GLM_CREDENTIAL_ENV EMBEDDING_PROVIDER EMBEDDING_MODEL \
  EMBEDDING_DIMENSION EMBEDDING_CREDENTIAL_ENV CKB_REPRO_MCP_COMMAND \
  CKB_REPRO_MCP_TRANSPORT

cjpm run --skip-build --run-args \
  "ckb-authority-bundle verify --authority $CKB_REPRO_DATASET_MANIFEST --delivery-root $(dirname "$CKB_REPRO_AUTHORITY_DELIVERY") --json" | \
  jq -e '.ok == true and .presentCount == 164'
```

通过标准：authority verify 退出 0；`work/runtime/qdrant/source` 四个路径在命令启动前均不存在（即使是空目录也会被拒绝）；candidate root 已存在、非空且已冻结；source 和 Qdrant 的冻结输入来自 composition 中的 source/snapshot 工件，不得预先写入上述运行路径。

## 2. 执行 production P8 认证

以下命令会启动真实 Student；只能在维护者明确授权后执行：

```bash
P8_JSON="$(cjpm run --skip-build --run-args \
  "ckb-repro-verify --mode run-certify --composition-manifest $CKB_REPRO_COMPOSITION_MANIFEST --work-root $CKB_WORK_ROOT --runtime-root $CKB_RUNTIME_ROOT --qdrant-root $CKB_QDRANT_ROOT --source-root $CKB_SOURCE_ROOT --candidate-root $CKB_CANDIDATE_ROOT --repository-root $CKB_REPRO_REPOSITORY_ROOT --p0-manifest $CKB_P0_MANIFEST --p1-score-contract $CKB_P1_SCORE_CONTRACT --p2-logical-snapshot $CKB_P2_LOGICAL_SNAPSHOT --p3-qdrant-snapshot $CKB_P3_QDRANT_SNAPSHOT --p4-build-proof $CKB_P4_BUILD_PROOF --p6-environment-lock $CKB_P6_ENVIRONMENT_LOCK --run-candidate-commit $RUN_CANDIDATE_COMMIT --json")"
printf '%s\n' "$P8_JSON" | jq -e '
  .ok == true and .strictPassed == 164 and .totalCases == 164 and
  .transportUnresolved == 0'
```

通过标准：P8 先完成 authority/environment/run-critical/composition/portable candidate 门禁，再执行生成与冻结评测两阶段；生成成功后必须产生 `generation-phase-seal.json`，冻结评测启动前必须按该清单验证全部既有 run 文件，篡改、新增文件或符号链接都必须阻断；stdout 只包含最终 P8 JSON，最终 JSON 精确满足 164/164。

失败处理：任何 preflight、restore、rebuild、generation 或 frozen evaluation 失败都停止当前 run。不得修改知识后续跑同一 run，不得跨 run 拼接结果。

## 3. 独立严格 gate

从冻结 composition 的 `runner_inputs` 取得 `runsRoot` 和 `runId`，设置：

```bash
: "${CERT_RUN_ROOT:?set exact runsRoot/runId from frozen runner inputs}"
GATE_JSON="$(cjpm run --skip-build --run-args \
  "cangjie-humaneval-pass1-gate --run-root $CERT_RUN_ROOT --manifest $CERT_RUN_ROOT/authority.jsonl --groups D --protocol completion-only-v1 --expected-total 164 --expected-pass 164 --format json")"
printf '%s\n' "$GATE_JSON" | jq -e '
  .ok == true and .releaseGate == "pass" and
  .expectedTotal == 164 and .expectedPass == 164 and
  .manifestCaseCount == 164 and .parsedResultRows == 164 and
  .baseMetricName == "strict_ckb_skill_base_pass_at_1" and
  .plusMetricName == "strict_ckb_skill_plus_pass_at_1" and
  .basePassed == 164 and .plusPassed == 164 and
  .certificationStatus == "passed" and
  (.diagnostics|length) == 0 and (.remainingGaps|length) == 0 and
  (.groups|length) == 1 and .groups[0].group == "D-ckb-mcp-http" and
  .groups[0].total == 164 and .groups[0].passAt1 == 164 and
  .groups[0].duplicates == 0 and .groups[0].missing == 0 and
  .groups[0].protocolViolations == 0 and
  .groups[0].transportParityFailures == 0'

jq -s -e 'length == 164 and all(.[];
  .certificationPassAt1 == true and .basePassed == true and
  .plusPassed == true and .sampleAttemptCount == 1 and
  .unresolvedTransport == 0 and .retryUsed == false and
  .fallbackUsed == false)' "$CERT_RUN_ROOT/results.jsonl"
```

通过标准：两个 `jq -e` 都退出 0。

## 4. 历史 W7 只读不变性检查

历史 W7 的 158/164 仅用于证明旧 reference 未被覆盖，不是当前 100% 目标的验收门槛：

```bash
jq -e '.strictPassed == 158 and .rawPassed == 160 and
       .businessFailed == 2 and .protocolInvalid == 2 and
       .transportUnresolved == 2' \
  reproducibility/manifests/reference-run.json >/dev/null
```

历史检查失败时停止发布，不得手工修改 reference。

## 5. 收尾

停止 P8 所属生命周期后确认没有残留 CKB、Qdrant 或 Runner 进程；保留本轮不可变证据并清理 P8 明确拥有的临时 root。不得删除生产 store、用户配置或其他 run。
