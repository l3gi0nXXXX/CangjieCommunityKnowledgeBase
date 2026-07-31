# 配置 Claude Code、GLM-5.2 与 CKB MCP

状态：`UNPUBLISHED_W3_DRAFT`。不可发布。

## 测试目标

目的：使用用户自己的临时环境变量和无凭据模板配置 Claude Code、GLM-5.2、
embedding 与 CKB MCP，同时保证凭据不进入输出或 settings。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| Claude Code | 版本与冻结 environment lock 一致 |
| GLM model | `GLM-5.2` |
| embedding | `bge-m3:latest`，dimension=1,024 |
| MCP | 指向本次临时 CKB service-http |
| 凭据扫描 | finding=0 |

通过标准：所有 identity 与最终冻结 manifest 精确一致，连通性探针通过且日志无凭据。

失败处理：identity 不一致时输出 `model_identity_mismatch_stop` 并停止，不改知识或 case。

## 重要边界

用户 key 只存在于当前 shell；不写仓库、Release、真实 HOME 或 Claude 用户 settings。
本草案中的 provider URL 是模板值，不是认证 provider identity。

## 第 1 步：创建临时配置目录

目的：避免读取或修改真实用户 settings。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro provider}"
export REPRO_HOME="${REPRO_ROOT}/empty home"
mkdir -p "${REPRO_HOME}/config"
cp reproducibility/configs/provider.example.env "${REPRO_HOME}/config/provider.env"
cp reproducibility/configs/claude-mcp.example.json "${REPRO_HOME}/config/claude-mcp.json"
echo 'template_copy_exit=0'
```

预期输出：

```text
template_copy_exit=0
```

通过标准：模板只复制到 `${REPRO_HOME}`，源文件和真实 settings 未改变。

失败处理：检查临时目录权限；不要复制到真实 HOME。

## 第 2 步：检查 Claude Code

目的：读取工具版本，不启动模型调用。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
"${CLAUDE_BIN:-claude}" --version \
  >"${REPRO_ROOT}/claude-version.stdout" \
  2>"${REPRO_ROOT}/claude-version.stderr"
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
exit=0
```

通过标准：退出码为 0；W7 后版本必须与冻结 environment lock 一致。

失败处理：查看两个版本日志；版本漂移时停止，不修改 lock 绕过。

## 第 3 步：注入用户凭据并准备 CKB 环境

目的：在不打印值的情况下确认凭据变量存在。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
test -n "${GLM_API_KEY:-}" || { echo 'provider_credential_missing'; exit 1; }
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/openssl@3/lib:${DYLD_LIBRARY_PATH:-}"
export cjHeapSize=4GB
echo 'credential_present=yes'
```

预期输出：

```text
credential_present=yes
```

通过标准：输出只说明存在性，不出现凭据值。

失败处理：在当前 shell 设置自己的变量后重试；不要写入配置模板。

## 第 4 步：检查 MCP 模板

目的：确认模板只指向本地 CKB HTTP transport。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
jq -e '.mcpServers.ckb.type == "http" and
       .mcpServers.ckb.url == "http://127.0.0.1:18890/mcp"' \
  reproducibility/configs/claude-mcp.example.json >/dev/null
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
exit=0
```

通过标准：模板与当前 `service-http` 的 `/mcp` 路由一致。

失败处理：不要手改受版本控制模板；先核对
`docs/service-http-operations.md` 和最终 environment lock。

## 待 W7 回填

GLM、embedding、REST/MCP stdio/MCP HTTP parity 探针要等 provider identity、
knowledge identity 和 Release asset 冻结后执行。任何模型漂移必须标记
`model_identity_mismatch_stop`；日志凭据 finding 非零必须立即停止。
