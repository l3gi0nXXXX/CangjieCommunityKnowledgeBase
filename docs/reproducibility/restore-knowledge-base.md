# 恢复 portable 知识库

状态：`UNPUBLISHED_W3_DRAFT`、`PENDING_W4_CLI_REGISTRATION`。不可发布。

## 测试目标

目的：发布后把逻辑快照和与其绑定的 Qdrant snapshot 恢复到全新临时目标，并验证
逻辑、向量、污染和三种查询 transport 一致。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| 逻辑目标 | 恢复前不存在 |
| raw | 7,818 |
| normalized/index/vector | 7,978 / 7,978 / 7,978 |
| dimension | 1,024 |
| leakage/path finding | 0 / 0 |
| REST/MCP stdio/MCP HTTP | parity diff=0 |

通过标准：全部字段来自同一 Release manifest 且完全一致。

失败处理：任一项不符时删除失败的临时目标并重新恢复，不手工补文件或 points。

## 重要边界

- 逻辑快照不含 Qdrant live storage；向量只能用独立 collection snapshot 恢复。
- 目标必须是新目录；不得原地覆盖生产 store。
- logical import、Qdrant bind 和 portable parity CLI 均待 W4 激活。

## 第 1 步：创建全新目标父目录

目的：验证目标不存在，防止覆盖已有知识。

工作目录：`${REPRO_ROOT}`。

命令：

```bash
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro restore}"
export CKB_RESTORE_ROOT="${REPRO_ROOT}/restored knowledge"
mkdir -p "${REPRO_ROOT}"
test ! -e "${CKB_RESTORE_ROOT}"
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
exit=0
```

通过标准：目标不存在且退出码为 0。

失败处理：选择新的临时目标；不要删除无法确认归属的目录。

## 第 2 步：检查当前发布状态

目的：在 Release 尚未生成时 fail closed。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
if rg -q 'UNPUBLISHED_W3_DRAFT' docs/reproducibility/restore-knowledge-base.md; then
  echo 'missing_asset_stop'
  exit 0
fi
```

预期输出：

```text
missing_asset_stop
```

通过标准：W3 草案明确停止，未创建恢复目标。

失败处理：若草案状态消失但没有经过 W7 证据回填，判定文档门禁失败。

## 第 3 步：准备服务环境

目的：确保恢复后的生产规模快照只在 4GB 堆门禁下启动。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/openssl@3/lib:${DYLD_LIBRARY_PATH:-}"
export cjHeapSize=4GB
printf 'heap=%s\n' "${cjHeapSize}"
```

预期输出：

```text
heap=4GB
```

通过标准：环境在服务进程启动前设置。

失败处理：返回[Service HTTP operations](../service-http-operations.md)，不得跳过堆门禁。

## 待 W4 激活的恢复步骤

W4 注册真实 CLI 后，本节才能加入可复制命令。激活顺序固定为：

1. 验证 `RELEASE-MANIFEST.json`、asset SHA-256 和签名；失败标记
   `hash_mismatch_stop`。
2. 执行 logical snapshot import。
3. 启动固定 digest 的 Qdrant，上传并恢复 collection snapshot。
4. 核对 green、7,978 points 和 1,024 维。
5. 扫描 raw、normalized、index、graph、Qdrant payload 和三个 transport；
   finding 大于 0 标记 `leakage_finding_stop`。
6. 重放 `retrieval-parity.json`，diff 必须为 0。

这些步骤当前标记为 `PENDING_W4_CLI_REGISTRATION`，不能被解释为已经可执行。
