# 快速开始

状态：`UNPUBLISHED_W3_DRAFT`、`PENDING_W4_CLI_REGISTRATION`。不可发布。本手册
当前只允许执行环境与源码检查；下载 Release、导入快照和恢复 Qdrant 要等 W4/W7。

## 测试目标

目的：发布后用最短路径恢复已验证知识并完成匿名查询，不执行源码重建或真实 164。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| 草案状态 | 当前必须看到 `UNPUBLISHED_W3_DRAFT` |
| 环境 | SDK、OpenSSL、`cjHeapSize=4GB` 已设置 |
| 发布物 | W7 后签名、hash 和 manifest 全部一致 |
| 服务 | health=200，MCP 初始化成功，PID 不漂移 |
| 清理 | 无 CKB 临时服务残留 |

通过标准：W3 只能通过安全准备步骤；任何发布身份占位符都会阻断后续恢复。

失败处理：不要猜测 tag、asset URL、hash 或 knowledgeVersion，等待 W7 定稿。

## 重要边界

路径可包含空格。示例只使用 `${CKB_ROOT}`、`${REPRO_ROOT}` 和
`${TMPDIR:-/tmp}`。不得把生产 `ckb-data` 用作草案测试目标。

## 第 1 步：准备临时根

目的：隔离下载、恢复和日志文件。

工作目录：任意目录。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro quick start}"
mkdir -p "${REPRO_ROOT}/logs"
printf 'draft=UNPUBLISHED_W3_DRAFT\n'
```

预期输出：

```text
draft=UNPUBLISHED_W3_DRAFT
```

通过标准：退出码为 0，目录位于用户指定的临时根。

失败处理：检查目录权限；不得改写仓库或生产 store。

## 第 2 步：准备 Cangjie 与服务堆

目的：满足当前已实现的构建和 service-http 启动契约。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
export cjHeapSize=4GB
cjpm build -i >"${REPRO_ROOT}/logs/build.stdout" 2>"${REPRO_ROOT}/logs/build.stderr"
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
exit=0
```

通过标准：退出码为 0，构建日志不含动态库错误。

失败处理：查看两个日志文件，再按
`docs/service-http-operations.md` 和 `troubleshooting.md` 处理。

## 第 3 步：发布恢复门禁

目的：阻止草案被误当成正式 Release。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
if rg -q 'UNPUBLISHED_W3_DRAFT|PENDING_W4_CLI_REGISTRATION' \
  docs/reproducibility/quick-start.md; then
  echo 'release_ready=no'
else
  echo 'release_ready=review_required'
fi
```

预期输出：

```text
release_ready=no
```

通过标准：W3 必须输出 `release_ready=no`。

失败处理：输出其他值时停止；不得自行填写 tag、Release 或 hash。

## 待 W4/W7 激活

以下名称来自已实现组件，但尚未在 `src/main.cj` 注册为用户 CLI：

- logical snapshot import：`PENDING_W4_CLI_REGISTRATION`
- Qdrant snapshot restore/bind：`PENDING_W4_CLI_REGISTRATION`
- release manifest/signature verification：`UNAVAILABLE_UNTIL_W7`

激活前不得把名称复制成 shell 命令。最终 quick start 还必须链接
[恢复知识库](restore-knowledge-base.md)、[服务运维](../service-http-operations.md)
和[故障处理](troubleshooting.md)。
