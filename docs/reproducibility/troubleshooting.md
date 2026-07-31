# 复现故障处理

状态：`UNPUBLISHED_W3_DRAFT`。不可发布。

## 测试目标

目的：把环境、恢复、provider、MCP、sandbox、identity 和污染问题定位到明确停止点，
不通过弱化门禁继续运行。

## 测试结论怎么判定

| 失败现象 | 判断 | 处理 |
|---|---|---|
| `cjpm` 不可用 | SDK 未加载 | 重新加载 SDK，不继续构建 |
| 动态库加载失败 | OpenSSL 路径缺失 | 修正环境变量后重试 |
| `ckb.service_heap_not_configured` | 未设置服务堆 | 启动前设置 `cjHeapSize=4GB` |
| `ckb.service_heap_invalid` | 堆值不可解析 | 使用 `4GB` 或 `4096MB` |
| `ckb.service_heap_too_small` | 低于 4,096MiB | 提高到至少 4GB |
| 启动时报 OOM | binary 或环境继承错误 | 先核对 commit 和 heap，不继续 164 |
| Qdrant points 非 7,978 | snapshot 错误或未恢复完 | 删除失败临时目标后重试 |
| dimension 非 1,024 | embedding/snapshot 漂移 | 停止绑定 |
| knowledge/hash 不一致 | tag、asset 或 source 漂移 | `hash_mismatch_stop` |
| provider 认证失败 | 凭据或 base URL 错误 | 只处理 transport，不改知识 |
| model 不是 GLM-5.2 | provider 路由漂移 | `model_identity_mismatch_stop` |
| MCP/parity 失败 | CKB 服务或协议错误 | 不计业务失败，不送 Teacher |
| leakage/path finding 非零 | 污染或机器路径 | `leakage_finding_stop` |
| authority mode=blocked | 许可证/来源未冻结 | `authority_delivery_blocked_stop` |
| unresolved transport 非零 | 重试预算耗尽 | `transport_unresolved_stop` |
| strict 与 raw 不同 | 协议门禁差异 | 对外只引用 strict |

通过标准：每个错误都在 Runner 或发布前停止，诊断不包含凭据、私有路径或大 payload。

失败处理：表中没有对应项时保存脱敏 stdout/stderr 和退出码，交给维护者；不要猜测
绕过参数。

## 第 1 步：收集环境诊断

目的：分别记录 SDK、OpenSSL 和 heap 状态，不读取用户 settings。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro diagnostics}"
mkdir -p "${REPRO_ROOT}"
{
  command -v cjpm || true
  printf 'heap_configured=%s\n' "$([ -n "${cjHeapSize:-}" ] && echo yes || echo no)"
  printf 'openssl_path_configured=%s\n' \
    "$([ -n "${DYLD_LIBRARY_PATH:-}" ] && echo yes || echo no)"
} >"${REPRO_ROOT}/environment.stdout" 2>"${REPRO_ROOT}/environment.stderr"
echo 'diagnostic_saved=yes'
```

预期输出：

```text
diagnostic_saved=yes
```

通过标准：诊断写入 `${REPRO_ROOT}`，没有输出凭据值。

失败处理：检查临时目录权限；不要把诊断提交到仓库。

## 第 2 步：服务启动问题

目的：使用唯一服务操作文档区分 heap、bind 和 OpenSSL 错误。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
test -f docs/service-http-operations.md
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
exit=0
```

通过标准：服务命令只以
[Service HTTP operations](../service-http-operations.md) 为准。

失败处理：缺少文档时停止，不从历史命令猜测启动参数。

## 第 3 步：确认没有残留临时服务

目的：结束手工验证后检查本次临时进程。

工作目录：任意目录。

命令：

```bash
pgrep -f 'cangjie_community_knowledge_base.*service-http' \
  >"${REPRO_ROOT}/residual-pids.stdout" 2>"${REPRO_ROOT}/residual-pids.stderr"
rc=$?
echo "pgrep_exit=${rc}"
```

预期输出：

```text
pgrep_exit=1
```

通过标准：退出码为 1 且 stdout 为空。

失败处理：只停止能确认属于本次 `${REPRO_ROOT}` 的进程；不要终止未知服务。
