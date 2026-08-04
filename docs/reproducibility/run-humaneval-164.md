# 运行真实 HumanEval 164

状态：W7 portable 参考运行已完成并冻结。

## 测试目标

目的：在固定知识、authority、provider、prompt、sandbox、MCP 和预算身份下执行 164 个独立样本；每个样本只有一个业务首样本。

## 测试结论怎么判定

| 项目 | W7 结果 |
|---|---|
| total | 164 |
| rawPassed | 160 |
| strictPassed / strictFailed | 158 / 6 |
| businessFailed | 2 |
| protocolInvalid | 2 |
| transportUnresolved | 2 |
| 发布门槛 | strict >= 151 |

通过标准：结果完整唯一且身份 hash 与 preflight 一致。本次 158/164 达到门槛；用户接受 2 个 unresolved transport，不再重试。

失败处理：新运行中的 transport 只按冻结预算处理；业务失败保留，不跨运行拼接。

## 重要边界

verifier 在答案冻结后运行，不进入 Student workspace、知识 store 或 MCP。门禁失败后不得继续 Runner 或发布。

## 第 1 步：创建独立运行目录

目的：隔离本轮产物。

工作目录：任意目录。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro humaneval}"
export RUN_ROOT="${REPRO_ROOT}/run-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${RUN_ROOT}"
echo 'run_root_created=yes'
```

预期输出：

```text
run_root_created=yes
```

通过标准：`${RUN_ROOT}` 是新目录且不在生产 store 内。

失败处理：选择新目录，不复用已有结果拼接样本。

## 第 2 步：执行认证 preflight

目的：在模型、知识或评测 identity 漂移时阻止 Runner。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
cjpm run --skip-build --run-args   "cangjie-certification-preflight --control-manifest ${CERTIFICATION_CONTROL:?set frozen control manifest}"
```

预期输出：preflight 允许启动，所有 identity 校验通过。

通过标准：退出码为 0；knowledgeVersion 为 `ckb-first-init-1-0-0-candidate`。

失败处理：输出 `model_identity_mismatch_stop`、`leakage_finding_stop` 或其他门禁诊断时停止。

## 第 3 步：运行 164 个样本

目的：从 000 到 163 各产生一个业务首样本。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cjpm run --skip-build --run-args   "cangjie-eval-abcde --control-manifest ${CERTIFICATION_CONTROL} --run-root ${RUN_ROOT}"
```

预期输出：164 个唯一结果和本轮汇总。

通过标准：不跨 run 拼接；如 transport 预算耗尽，记录 `transport_unresolved_stop` 并如实计入本轮。

失败处理：不得修改知识后在同一认证 run 重试业务失败。

## 第 4 步：核对冻结参考结果

目的：确认公开 W7 数值没有被后续运行覆盖。

工作目录：`${CKB_ROOT}`。

命令：

```bash
jq -e '.strictPassed == 158 and .rawPassed == 160 and
       .businessFailed == 2 and .protocolInvalid == 2 and
       .transportUnresolved == 2'   reproducibility/manifests/reference-run.json >/dev/null
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：退出码为 0。

失败处理：停止发布，不手工修改冻结结果。
