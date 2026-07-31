# CKB 可复现发布手册

状态：`UNPUBLISHED_W3_DRAFT`、`PENDING_W4_CLI_REGISTRATION`。这是不可发布的
W3 草案。P8-A/P5 最终产物尚未生成，文档不提供虚构 tag、Release、hash、
knowledgeVersion 或 portable 成绩。

## 测试目标

目的：让复现者按固定顺序完成材料校验、知识恢复或重建、服务检查、独立 164
测试和严格计分，并在任何身份漂移时停止。

## 测试结论怎么判定

| 项目 | W3 草案要求 | 最终发布要求 |
|---|---|---|
| 文档与链接 | 自动门禁通过 | 相同 |
| 发布身份 | 必须保持未发布占位符 | W7 写入 P8-A/P5 实际值 |
| 逻辑知识 | 不在 W3 声称已生成 | raw=7,818，normalized/index=7,978 |
| 向量 | 不在 W3 声称已生成 | points=7,978，dimension=1,024 |
| 污染 | 文档禁止泄漏 | 全层 finding=0 |
| strict | 只说明历史迁移基线 | 引用一次独立 P8-A 实际结果 |

通过标准：所有手册命令有目的、工作目录、预期输出、通过标准和失败处理；当前未注册
命令不能被写成可执行步骤。

失败处理：只要看到 `UNPUBLISHED_W3_DRAFT`、`UNPUBLISHED_P8_A_REFERENCE`、
`UNAVAILABLE_UNTIL_W7` 或 `PENDING_W4_CLI_REGISTRATION`，就停止正式复现或发布。

## 重要边界

- authority、verifier 和 hidden tests 属于评测平面，不得进入知识快照或 MCP 响应。
- 用户凭据只通过当前 shell 环境注入，不写仓库、Release 或用户 settings。
- 路径可包含空格；所有示例使用带引号的 `${CKB_ROOT}`、`${REPRO_ROOT}` 和
  `${TMPDIR:-/tmp}`。
- 规划中的 release import、source rebuild、strict-score 等 CLI 要等 W4 在
  `src/main.cj` 注册后才可执行。
- 门禁失败后不得继续 Runner 或发布。

## 推荐顺序

1. [快速开始](quick-start.md)
2. 选择[恢复知识库](restore-knowledge-base.md)或[从源码重建](rebuild-from-source.md)
3. [配置 Claude Code 与 GLM-5.2](configure-claude-glm.md)
4. [运行 HumanEval 164](run-humaneval-164.md)
5. [严格计分](verify-strict-pass-at-1.md)
6. 阅读[结果口径](result-interpretation.md)
7. 出错时查看[故障处理](troubleshooting.md)

维护者另见[发布维护手册](release-maintainer-runbook.md)。服务启动只引用现有
[Service HTTP operations](../service-http-operations.md)。

## 第 1 步：建立安全工作根

目的：所有恢复、下载和日志写入临时目录，不修改生产 store 或用户配置。

工作目录：任意目录。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT to the repository root}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro draft}"
mkdir -p "${REPRO_ROOT}"
printf 'CKB_ROOT_SET=yes\nREPRO_ROOT_SET=yes\n'
```

预期输出：

```text
CKB_ROOT_SET=yes
REPRO_ROOT_SET=yes
```

通过标准：退出码为 0，且 `${REPRO_ROOT}` 不指向生产知识目录。

失败处理：修正变量后重试；不得改用隐式当前目录或用户 settings。
