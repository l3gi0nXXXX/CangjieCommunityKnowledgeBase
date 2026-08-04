# 恢复 portable 知识库

状态：W7 身份已冻结；发布 archive 的下载位置由 W11 定稿。

## 测试目标

目的：把发布 archive 恢复到全新临时目标，并验证逻辑知识、向量和检索一致性。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| 目标 | 恢复前不存在 |
| knowledgeVersion | `ckb-first-init-1-0-0-candidate` |
| records / vector points | 7,817 / 7,817 |
| dimension | 1,024 |
| leakage/path finding | 0 / 0 |
| REST/MCP stdio/MCP HTTP | parity diff=0 |

通过标准：全部字段来自同一发布 manifest，且恢复目标保持隔离。

失败处理：删除能确认归属本次测试的失败目标后重试，不覆盖生产 store。

## 重要边界

逻辑快照不含 Qdrant live storage；目标必须是新目录，用户必须先验证普通 tag、release commit 和 SHA-256。

## 第 1 步：创建恢复目标

目的：防止覆盖已有知识。

工作目录：任意目录。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro restore}"
export CKB_RESTORE_ROOT="${REPRO_ROOT}/restored-knowledge"
mkdir -p "${REPRO_ROOT}"
test ! -e "${CKB_RESTORE_ROOT}"
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：目标不存在。

失败处理：选择新的隔离目标，不删除未知目录。

## 第 2 步：导入已验证 archive

目的：使用已注册的 release import，不手工解包拼接。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
cjpm run --skip-build --run-args   "ckb-release-import --archive ${CKB_RELEASE_ARCHIVE:?set verified archive} --target-root ${CKB_RESTORE_ROOT} --json"
```

预期输出：JSON 中 `ok=true`、`diagnostic=ok`。

通过标准：退出码为 0，恢复后的版本、7,817 条记录和 manifest hash 一致。

失败处理：archive 缺失时标记 `missing_asset_stop`；hash 不一致时标记
`hash_mismatch_stop`；不得继续启动服务。

## 第 3 步：验证服务与 parity

目的：确认恢复结果可被三种 transport 一致读取。

工作目录：`${CKB_ROOT}`。

命令：

```bash
export OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
export cjHeapSize=4GB
cjpm run --skip-build --run-args "--store ${CKB_RESTORE_ROOT} service-http"
```

预期输出：服务启动，health 返回 200。

通过标准：向量点 7,817、维度 1,024、parity diff=0。

失败处理：停止本次临时服务，按[服务运维](../service-http-operations.md)排查。
