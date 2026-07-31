# 严格 pass@1 计分与证据复算

状态：`UNPUBLISHED_W3_DRAFT`、`UNPUBLISHED_P8_A_REFERENCE`、
`UNAVAILABLE_UNTIL_W7`。不可发布。

## 测试目标

目的：分别重算 portable 公共参考证据和用户自己的独立 run，避免把 raw、
historical baseline、strict score 和 164/164 release gate 混为一谈。

## 测试结论怎么判定

| 结果 | 来源 | W3 状态 |
|---|---|---|
| 历史 raw 158/164 | 路径治理前历史迁移基线 | 仅迁移对照 |
| 历史 strict 151/164 | 同一历史 run | 仅迁移对照 |
| portable reference | P8-A 单轮真实 164 | `UNPUBLISHED_P8_A_REFERENCE` |
| current run | 用户本轮独立结果 | 每轮如实计算 |
| release gate 164/164 | 发布流程完整性 | 不是模型 pass@1 |

通过标准：公共 asset hash、portable identity、164 行证据和 manifest 完全一致；
计分器输出 `valid=true`，结果只引用对应 run。

失败处理：hash、identity、行数或 transport 状态不符时停止，不按 case 挑选其他运行。

## 重要边界

`cangjie-humaneval-strict-score` 的实现与组件测试已经存在，但尚未在
`src/main.cj` 注册；本命令为“待 W4 激活”，当前不得当作 `cjpm run` 用户命令。

## 第 1 步：确认 portable reference 尚未发布

目的：防止把历史 151 填入 portable reference。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
test ! -e reproducibility/manifests/reference-run.json
rc=$?
echo "reference_absent_exit=${rc}"
```

预期输出：

```text
reference_absent_exit=0
```

通过标准：W3 没有虚构 `reference-run.json`。

失败处理：如果文件存在，必须确认它来自 P8-A 且通过 P5/W7 门禁，否则停止发布。

## 第 2 步：校验历史 manifest 只作对照

目的：确认历史证据仍可审计，但不冒充 portable 结果。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
jq -e '.strictPassed == 151 and .rawPassed == 158 and
       .strictFailed == 13 and .transportUnresolved == 0' \
  reproducibility/manifests/historical-reference-run.json >/dev/null
rc=$?
echo "historical_manifest_exit=${rc}"
```

预期输出：

```text
historical_manifest_exit=0
```

通过标准：退出码为 0，并且引用时明确写“历史迁移基线”。

失败处理：manifest 漂移时停止，不手工修正数值。

## 待 W4/W7 激活

W4 注册 `cangjie-humaneval-strict-score` 后，W7 才能写入以下两条真实命令：

1. 使用 `--public-evidence` 重算 portable 公共参考证据；
2. 使用 `--public-evidence --run-root --manifest` 复核用户本轮产物。

最终预期 JSON 必须来自真实输出，至少包含 `valid`、`strictPassed`、
`strictFailed`、`rawPassed`、`transportUnresolved` 和 portable identity。
hash 不一致时输出 `hash_mismatch_stop`。本草案不填写 portable 数值。
