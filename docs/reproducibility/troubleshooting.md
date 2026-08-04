# 复现故障处理

状态：适用于 W7 冻结结果及后续 W11 发布物。

## 测试目标

目的：把环境、恢复、provider、MCP、sandbox、identity 和污染问题定位到明确停止点。

## 测试结论怎么判定

| 失败现象 | 判断 | 处理 |
|---|---|---|
| `cjpm` 不可用 | SDK 未加载 | 重新加载 SDK |
| 动态库加载失败 | OpenSSL 路径缺失 | 修正环境变量 |
| service heap 错误 | 未设置或低于 4GB | 设置 `cjHeapSize=4GB` |
| 启动时报 OOM | binary 或环境继承错误 | 核对 commit 和 heap |
| Qdrant points 非 7,817 | snapshot 错误 | 删除本次失败目标后重试 |
| dimension 非 1,024 | embedding/snapshot 漂移 | 停止绑定 |
| knowledge/hash 不一致 | 源码或 asset 漂移 | `hash_mismatch_stop` |
| provider 认证失败 | 凭据或 base URL 错误 | 只处理 transport |
| model 不是 GLM-5.2 | provider 路由漂移 | `model_identity_mismatch_stop` |
| MCP/parity 失败 | 服务或协议错误 | 不计业务失败 |
| leakage/path finding 非零 | 污染或机器路径 | `leakage_finding_stop` |
| authority 交付失败 | 许可证或来源错误 | `authority_delivery_blocked_stop` |
| 新运行 unresolved transport 非零 | 重试预算耗尽 | `transport_unresolved_stop` |
| strict 与 raw 不同 | 协议门禁差异 | 对外只引用 strict |

通过标准：诊断不包含凭据、私有路径或大 payload，且错误不会被弱化为通过。

失败处理：保存脱敏 stdout/stderr 和退出码，交给维护者；不要猜测绕过参数。

## 第 1 步：收集环境诊断

目的：记录 SDK、OpenSSL 和 heap 状态，不读取用户 settings。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro diagnostics}"
mkdir -p "${REPRO_ROOT}"
{
  command -v cjpm || true
  printf 'heap_configured=%s\n' "$([ -n "${cjHeapSize:-}" ] && echo yes || echo no)"
  printf 'openssl_path_configured=%s\n'     "$([ -n "${DYLD_LIBRARY_PATH:-}" ] && echo yes || echo no)"
} >"${REPRO_ROOT}/environment.stdout" 2>"${REPRO_ROOT}/environment.stderr"
echo 'diagnostic_saved=yes'
```

预期输出：

```text
diagnostic_saved=yes
```

通过标准：诊断位于隔离目录且不含凭据。

失败处理：检查临时目录权限，不提交诊断文件。

## 第 2 步：确认服务已清理

目的：结束手工验证后检查本次临时进程。

工作目录：任意目录。

命令：

```bash
pgrep -f 'cangjie_community_knowledge_base.*service-http'   >"${REPRO_ROOT}/residual-pids.stdout" 2>"${REPRO_ROOT}/residual-pids.stderr"
echo "pgrep_exit=$?"
```

预期输出：

```text
pgrep_exit=1
```

通过标准：stdout 为空；服务细节以[Service HTTP operations](../service-http-operations.md)为准。

失败处理：只停止能确认属于本次 `${REPRO_ROOT}` 的进程。
