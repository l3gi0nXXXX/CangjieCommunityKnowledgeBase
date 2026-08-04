# HumanEval 结果口径

状态：W7 portable 参考结果已冻结。

## 测试目标

目的：规定 historical、portable reference、current run、raw、strict 和 release gate 的唯一口径。

## 测试结论怎么判定

| 名称 | 含义 | 可否作为 portable 成绩 |
|---|---|---|
| 历史 raw 158/164、strict 151/164 | 路径治理前历史迁移基线 | 否，仅历史对照 |
| portable raw 160/164、strict 158/164 | W7 独立真实 164 | 是 |
| current run | 用户本轮在线实验 | 只代表本轮 |
| 发布完整性门禁 | 工件与证据完整 | 不是模型成绩 |

通过标准：每个数值都回溯到单一 run、固定 identity 和严格计分；不得跨 run 拼接。

失败处理：无法证明 run identity 或 evidence hash 时不引用结果。

## 第 1 步：核对结果来源

目的：确认 portable 与历史对照没有混写。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
jq -e '.baselineKind == "portable_release" and
       .strictPassed == 158 and .rawPassed == 160'   reproducibility/manifests/reference-run.json >/dev/null
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：当前 portable 成绩为 strict 158/164，历史 151/164 只在文字对照中出现。

失败处理：停止引用，不把历史 raw 或 strict 填入 portable reference。

## 允许的表述

- “路径治理前历史基线 strict 为 151/164，raw 为 158/164。”
- “W7 portable 参考运行 strict 为 158/164，raw 为 160/164。”
- “本次结果包含 2 个 protocol invalid 和 2 个 transport unresolved，用户接受且不再重试。”

## 禁止的表述

- 把历史 151 称为 portable 成绩；
- 把 raw 160 称为 strict pass@1；
- 拼接多轮或不同实验臂的成功样本；
- 把合成集成测试或发布完整性门禁称为模型 pass@1。
