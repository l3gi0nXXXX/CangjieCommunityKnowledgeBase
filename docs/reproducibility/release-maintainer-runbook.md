# 发布维护手册

状态：W7 结果与文档已回填；W8—W11 尚需完成 bundle、clean-room、普通 tag 和 Release，不使用 GPG 签名。

## 测试目标

目的：规定 W7 之后的单向发布门禁，防止未验证身份或工件进入发布。

## 测试结论怎么判定

| 阶段 | 必须事实 |
|---|---|
| W7 | strict=158/164，raw=160/164，reference 与公共证据冻结 |
| W8 | unsigned bundle 只来自冻结输入 |
| W9 | clean-room 独立复验 |
| W10 | promotion 与最终 bundle |
| W11 | 普通 tag、Release 和下载回验 |

通过标准：前一阶段通过后才执行下一阶段；tag 和 Release URL 只由 W11 写入。

失败处理：任一门禁失败即停止，不覆盖旧 asset、不降低 strict>=151 门槛。

## 重要边界

- 不强制添加被忽略的生产知识、配置、凭据或生成资产。
- authority 和评测工件不进入知识平面。
- W7 reference 为 `reproducibility/manifests/reference-run.json`。
- 当前 public evidence hash 为 `sha256:5e7fbb60be8bb6c8660a758cbf86d432103c748130fddbe29f6885e552fe4516`。

## 第 1 步：文档发布模式门禁

目的：确认公开入口没有草案标记、本机路径、凭据或未知命令。

工作目录：`${CKB_ROOT}/test`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}/test"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
cjpm test -j 1 --filter CkbReproDocumentationTest
echo "exit=$?"
```

预期输出：`FAILED: 0` 且 `exit=0`。

通过标准：全部文档契约测试通过。

失败处理：按失败测试修正文档，不放宽路径、凭据或评测污染扫描。

## 第 2 步：核对 W7 证据

目的：保证结果、知识身份和公共证据同源。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
jq -e '.strictPassed == 158 and .rawPassed == 160 and
       .knowledgeVersion == "ckb-first-init-1-0-0-candidate"'   reproducibility/manifests/reference-run.json >/dev/null
test "${CKB_PUBLIC_EVIDENCE_HASH:?set observed hash}" =   "sha256:5e7fbb60be8bb6c8660a758cbf86d432103c748130fddbe29f6885e552fe4516"
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：退出码为 0，strict 158 >= 151。

失败处理：停止 bundle 与 promotion，不修改 reference 或证据。

## 第 3 步：W11 定稿

目的：只在 clean-room、普通 tag/commit 绑定和下载回验通过后发布身份。

工作目录：`${CKB_ROOT}`。

命令：

```bash
test -n "${CKB_RELEASE_TAG:-}" &&
test -n "${CKB_RELEASE_URL:-}" &&
test -n "${CKB_RELEASE_ARCHIVE:-}"
echo "exit=$?"
```

预期输出：W11 完成后为 `exit=0`。

通过标准：普通 tag、完整 commit SHA、URL 和 archive SHA-256 相互绑定，并从公开地址下载回验。

失败处理：W11 完成前保持“待定稿”，不得虚构 URL。
