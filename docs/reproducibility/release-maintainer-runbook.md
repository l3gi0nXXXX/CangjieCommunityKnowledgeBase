# 发布维护手册

状态：`UNPUBLISHED_W3_DRAFT`、`UNAVAILABLE_UNTIL_W7`。不可发布。

## 测试目标

目的：规定从 W3 文档草案到 W7 结果回填、W8/W9 clean-room 验证和最终签名发布的
单向门禁，避免草案占位符进入正式材料。

## 测试结论怎么判定

| 阶段 | 必须事实 |
|---|---|
| W3 | 文档与自动门禁存在，所有发布身份仍为占位符 |
| W4 | CLI 已注册，run-critical manifest 全部 frozen |
| W5 | portable 逻辑、向量、快照与 parity 工件完成 |
| W6 | P8-A 独立真实 164 完成 |
| W7 | 仅 `target_matched` 才回填结果与命名 |
| W8/W9 | unsigned bundle 和 clean-room 复验通过 |
| W10/W11 | promotion、签名、tag、Release 和下载回验通过 |

通过标准：前一阶段证据未通过时，下游调用数为 0；正式文档不含任何未发布占位符。

失败处理：任一门禁失败即停止，不改分数目标、不覆盖旧 asset、不跳过签名。

## 重要边界

- 不强制添加被忽略的生产知识、配置、凭据或生成资产。
- 不在 W3 创建 tag、Release、签名、最终 manifest 或 reference-run。
- portable P8-A strict 不等于目标时进入 `scoreMismatchHold`，不自动换发布名。
- authority 和评测工件不进入知识平面。

## 第 1 步：W3 占位符门禁

目的：证明当前文档不能被发布。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
rg -l 'UNPUBLISHED_W3_DRAFT|UNPUBLISHED_P8_A_REFERENCE|UNAVAILABLE_UNTIL_W7' \
  README.md docs/reproducibility >"${TMPDIR:-/tmp}/ckb-repro-placeholders.txt"
rc=$?
echo "placeholder_scan_exit=${rc}"
```

预期输出：

```text
placeholder_scan_exit=0
```

通过标准：W3 必须至少找到一个占位符；正式发布门禁则必须反向要求 finding=0。

失败处理：W3 没有占位符时停止合并；W7 只能按真实 P8-A/P5 manifest 回填。

## 第 2 步：自动文档门禁

目的：检查文件、链接、命令边界、portable 变量和敏感内容。

工作目录：`${CKB_ROOT}/test`。

命令：

```bash
cd "${CKB_ROOT}/test"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/openssl@3/lib:${DYLD_LIBRARY_PATH:-}"
cjpm test -j 1 --filter CkbReproDocumentationTest
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
PASSED: 6
FAILED: 0
exit=0
```

通过标准：6 个 P7 文档测试全部通过。

失败处理：按失败 Test ID 修正文档；不得放宽扫描规则来容纳真实凭据或私有路径。

## 第 3 步：W7 回填前置

目的：保证结果、知识身份和公共证据来自同一 P8-A run。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
test -f reproducibility/manifests/reference-run.json &&
test -f "${REPRO_ROOT:?set REPRO_ROOT}/ckb-public-reference-evidence.tar.zst"
rc=$?
echo "w7_inputs_exit=${rc}"
```

预期输出：

```text
w7_inputs_exit=0
```

通过标准：只在 W7 真实产物存在并通过 hash/identity 门禁时回填。

失败处理：输出非 0 时保持 `UNAVAILABLE_UNTIL_W7`，不创建占位文件。

## 后续发布

签名 tag、Release、asset hash 和下载回验命令必须在 P9 实现并由 W11 定稿后加入。
当前没有 canonical tag 或 Release URL；维护者应返回[复现导航](README.md)检查状态。
