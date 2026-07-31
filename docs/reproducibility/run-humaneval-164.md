# 运行真实 HumanEval 164

状态：`UNPUBLISHED_W3_DRAFT`、`UNAVAILABLE_UNTIL_W7`。不可发布。

## 测试目标

目的：在固定知识、authority、provider、prompt、sandbox、MCP 和预算身份下执行
case 000—163；transport 重试不产生业务样本，业务样本每 case 最多一个。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| authority cases | 164，唯一 |
| case range | 000—163 |
| business samples | 每 case 1 个 |
| transport unresolved | 0 |
| CKB evidence | treatment arm 每 case 符合冻结策略 |
| strict score | 由独立 strict-score 步骤计算 |

通过标准：164 个结果完整唯一，transport unresolved=0，所有身份 hash 与 preflight
一致，没有业务重试或跨运行拼接。

失败处理：transport 失败只按冻结预算重试；业务失败保留为失败，不修改知识后重跑同一
认证 run。

## 重要边界

authority 交付当前为 blocked。verifier 只在答案冻结后由验证进程使用，不进入
Student workspace、知识 store 或 MCP。门禁失败后不得继续 Runner 或发布。

## 第 1 步：创建独立 run root

目的：隔离本轮产物，不覆盖历史运行或生产知识。

工作目录：任意目录。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro humaneval}"
export RUN_ROOT="${REPRO_ROOT}/run-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${RUN_ROOT}"
printf 'run_root_created=yes\n'
```

预期输出：

```text
run_root_created=yes
```

通过标准：`${RUN_ROOT}` 是本轮新目录，且不在生产 store 内。

失败处理：选择新的临时根；不得复用已有 result 目录拼接 case。

## 第 2 步：校验 authority delivery

目的：在许可证、来源和 164-case identity 未冻结时停止。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
mode="$(jq -r '.mode' reproducibility/manifests/authority-delivery.json)"
if [ "${mode}" = "blocked" ]; then
  echo 'authority_delivery_blocked_stop'
  exit 0
fi
echo "authority_mode=${mode}"
```

预期输出：

```text
authority_delivery_blocked_stop
```

通过标准：W3 必须 fail closed；没有 Runner 进程启动。

失败处理：只能由 P6 冻结许可证和公开交付材料，不能自行换数据集。

## 第 3 步：验证当前 Runner CLI 名称

目的：只使用 `src/main.cj` 已注册的命令，不启动真实 case。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/openssl@3/lib:${DYLD_LIBRARY_PATH:-}"
cjpm run --skip-build --run-args "cangjie-eval-abcde --help" \
  >"${RUN_ROOT}/runner-help.stdout" 2>"${RUN_ROOT}/runner-help.stderr"
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
exit=0
```

通过标准：help 中包含 `--case-start 0 --case-end 163`、certification identity 参数
和 `--model-timeout-seconds`。

失败处理：查看两个文件；命令名或参数不一致时以当前源码为准修订手册。

## 第 4 步：preflight 草案门禁

目的：避免用占位 identity 启动认证运行。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
test "${CKB_REPRO_RELEASE_STATUS:-UNPUBLISHED_W3_DRAFT}" = "PUBLISHED" || {
  echo 'missing_asset_stop'
  exit 0
}
```

预期输出：

```text
missing_asset_stop
```

通过标准：W3 停在 Runner 前。

失败处理：不得手工设置 PUBLISHED 绕过；等待 W7 提供冻结 control manifest。

## W7 最终运行顺序

W7 必须补入实际 `cangjie-certification-preflight --control-manifest` 命令和完整
`cangjie-eval-abcde` certification 参数。顺序固定为：

1. authority manifest 164-case 唯一性与 dataset hash 校验；
2. preflight 核对知识、模型、prompt、group、tool/MCP、local docs 和预算；
3. 从 000 到 163；
4. transport 重试不产生业务样本；
5. 每 case 业务样本最多一个；
6. `transportUnresolved=0`，否则 `transport_unresolved_stop`；
7. 调用 W4 激活的 strict-score CLI。

任何缺 asset、hash、model 或 leakage 门禁失败都必须在 Runner 前停止。
