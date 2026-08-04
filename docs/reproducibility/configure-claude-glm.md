# 配置 Claude Code、GLM-5.2 与 CKB MCP

状态：W7 参考身份已冻结；复现者使用自己的 provider 凭据。

## 测试目标

目的：配置 Claude Code、GLM-5.2 和本地 CKB MCP，同时保证凭据不进入仓库、输出或用户 settings。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| model | GLM-5.2 |
| knowledgeVersion | `ckb-first-init-1-0-0-candidate` |
| embedding dimension | 1,024 |
| MCP | 本次临时 CKB service-http |
| 凭据扫描 | finding=0 |

通过标准：模型与知识身份固定，MCP 初始化成功，日志无凭据。

失败处理：身份不一致时输出 `model_identity_mismatch_stop` 并停止，不改知识或样本。

## 重要边界

用户 key 只存在于当前 shell；不写仓库、发布物、真实 HOME 或 Claude 用户 settings。

## 第 1 步：创建临时配置

目的：避免修改真实用户配置。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro provider}"
export REPRO_HOME="${REPRO_ROOT}/empty-home"
mkdir -p "${REPRO_HOME}/config"
cp reproducibility/configs/provider.example.env "${REPRO_HOME}/config/provider.env"
cp reproducibility/configs/claude-mcp.example.json "${REPRO_HOME}/config/claude-mcp.json"
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：模板只复制到临时目录。

失败处理：检查临时目录权限，不复制到真实 HOME。

## 第 2 步：准备运行环境

目的：只确认凭据存在，不打印值。

工作目录：`${CKB_ROOT}`。

命令：

```bash
test -n "${GLM_API_KEY:-}" || { echo 'provider_credential_missing'; exit 1; }
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
export cjHeapSize=4GB
echo 'credential_present=yes'
```

预期输出：

```text
credential_present=yes
```

通过标准：输出不含凭据值。

失败处理：只在当前 shell 设置自己的变量；认证失败只处理 transport。

## 第 3 步：检查 MCP 模板

目的：确认模板使用本地 HTTP transport。

工作目录：`${CKB_ROOT}`。

命令：

```bash
jq -e '.mcpServers.ckb.type == "http" and
       .mcpServers.ckb.url == "http://127.0.0.1:18890/mcp"'   reproducibility/configs/claude-mcp.example.json >/dev/null
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：模板与当前 service-http 的 `/mcp` 路由一致。

失败处理：参考[服务运维](../service-http-operations.md)，不修改受版本控制模板绕过。
