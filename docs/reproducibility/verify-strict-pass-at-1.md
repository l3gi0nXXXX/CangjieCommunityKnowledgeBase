# 严格 pass@1 计分与证据复算

状态：W7 portable 参考结果已冻结。

## 测试目标

目的：区分 portable reference、用户当前运行、raw、strict 和发布完整性门禁。

## 测试结论怎么判定

| 结果 | 来源 | 用途 |
|---|---|---|
| 历史 raw 158/164、strict 151/164 | 路径治理前历史迁移基线 | 仅历史对照 |
| portable raw 160/164、strict 158/164 | W7 独立真实 164 | 当前发布参考 |
| current run | 用户独立运行 | 只代表本轮 |
| 发布门禁 | 工件完整性 | 不是模型 pass@1 |

通过标准：公共证据 hash、portable identity、164 条证据和 manifest 一致；strict 158 >= 151。

失败处理：hash、identity、计数或状态不符时停止，不挑选其他运行中的样本。

## 重要边界

严格计分组件由认证与发布验证链调用；用户不得绕过 preflight 或直接修改结果 JSON。

## 第 1 步：检查 reference manifest

目的：确认 W7 结果字段完整。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
jq -e '.totalCases == 164 and .rawPassed == 160 and
       .strictPassed == 158 and .strictFailed == 6 and
       .businessFailed == 2 and .protocolInvalid == 2 and
       .transportUnresolved == 2 and
       .knowledgeVersion == "ckb-first-init-1-0-0-candidate"'   reproducibility/manifests/reference-run.json >/dev/null
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：退出码为 0；所有字段来自同一个 reference manifest。

失败处理：标记 `hash_mismatch_stop` 并停止。

## 第 2 步：核对公共证据 hash

目的：保证公开证据与 W7 reference 同源。

工作目录：`${CKB_ROOT}`。

命令：

```bash
test "${CKB_PUBLIC_EVIDENCE_HASH:?set observed hash}" =   "sha256:5e7fbb60be8bb6c8660a758cbf86d432103c748130fddbe29f6885e552fe4516"
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：hash 精确匹配。

失败处理：停止证据复算和发布，不替换 reference。
