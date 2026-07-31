# HumanEval 结果口径

状态：`UNPUBLISHED_W3_DRAFT`、`UNPUBLISHED_P8_A_REFERENCE`。不可发布。

## 测试目标

目的：规定 historical、portable reference、current run、raw、strict 和 release
gate 的唯一口径。

## 测试结论怎么判定

| 名称 | 含义 | 可否作为 portable 成绩 |
|---|---|---|
| 历史 raw 158/164 | 路径治理前首个业务样本单测 | 否 |
| 历史 strict 151/164 | 同一历史 run 的最终严格结果 | 否，仅迁移对照 |
| portable reference | P8-A 在新知识上的独立真实 164 | W7 后才可引用 |
| current run | 用户本轮在线实验 | 只代表本轮 |
| 164/164 release gate | 发布工件完整性 | 不是模型成绩 |

通过标准：每个数值都能回溯到单一 run、固定 identity 和严格计分 JSON；不得跨 run
拼接。

失败处理：无法证明 run identity 或 evidence hash 时不引用结果。

## 第 1 步：检查引用文本

目的：在发布前发现把历史结果误写成 portable 结果的文案。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
rg -n 'UNPUBLISHED_P8_A_REFERENCE|历史迁移基线' \
  docs/reproducibility README.md
rc=$?
echo "exit=${rc}"
```

预期输出：

```text
至少一行未发布占位符和至少一行“历史迁移基线”
exit=0
```

通过标准：W3 文档保留未发布边界，历史数值没有被写成 portable 新结果。

失败处理：恢复占位符并运行文档门禁；不得自行填入 151。

## 允许的表述

- “路径治理前历史基线 strict 为 151/164，raw 为 158/164。”
- “本次 portable 在线实验 strict 为 N/164”，前提是引用本轮独立证据。

## 禁止的表述

- 把历史 151 称为 portable 知识成绩；
- 把 raw 158 称为最终 strict pass@1；
- 拼接多轮、transport 重试或不同实验臂的成功 case；
- 把合成集成测试称为真实 Claude Code、GLM-5.2 成绩；
- 把 164/164 发布门禁称为模型 pass@1。
