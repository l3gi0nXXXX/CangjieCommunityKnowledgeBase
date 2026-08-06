# CKB 可复现发布手册

状态：W7 参考结果已冻结；普通 tag 与 Release URL 由 W11 定稿，不使用 GPG 签名。

## 测试目标

目的：让复现者按固定顺序校验材料、恢复或重建知识、检查服务、独立运行 164 个样本并严格计分。

## 测试结论怎么判定

| 项目 | W7 冻结值 |
|---|---|
| knowledgeVersion | `ckb-first-init-1-0-0-candidate` |
| records / vector points | 7,817 / 7,817 |
| vector dimension | 1,024 |
| raw pass@1 | 160/164 |
| strict pass@1 | 158/164 |
| businessFailed / protocolInvalid / transportUnresolved | 2 / 2 / 2 |
| 发布门槛 | strict >= 151 |
| reference manifest | `reproducibility/manifests/reference-run.json` |
| public evidence hash | `sha256:5e7fbb60be8bb6c8660a758cbf86d432103c748130fddbe29f6885e552fe4516` |

通过标准：身份、计数和 hash 均与 reference manifest 一致；本次 158/164 已达到发布门槛，用户接受 2 个 unresolved transport，不再重试。

失败处理：任一身份或 hash 漂移立即停止，不拼接其他运行，也不修改知识后重跑本次认证结果。

## 重要边界

- authority、verifier 和 hidden tests 属于评测平面，不进入知识快照或 MCP。
- 用户凭据仅由当前 shell 注入，不写仓库、发布物或真实用户 settings。
- 路径可包含空格；示例使用 `${CKB_ROOT}`、`${REPRO_ROOT}` 和 `${TMPDIR:-/tmp}`。
- W11 完成前不虚构 tag 或 Release URL。

## 推荐顺序

1. [快速开始](quick-start.md)
2. 选择[恢复知识库](restore-knowledge-base.md)或[从源码重建](rebuild-from-source.md)
3. [配置 Claude Code 与 GLM-5.2](configure-claude-glm.md)
4. [冻结 HumanEval+ authority delivery](freeze-humaneval-authority-delivery.md)
5. [运行 HumanEval 164](run-humaneval-164.md)
6. [严格计分](verify-strict-pass-at-1.md)
7. 阅读[结果口径](result-interpretation.md)
8. 出错时查看[故障处理](troubleshooting.md)

维护者另见[发布维护手册](release-maintainer-runbook.md)和[Service HTTP operations](../service-http-operations.md)。

## 第 1 步：建立隔离工作根

目的：所有恢复、下载和日志写入临时目录，不修改生产 store。

工作目录：任意目录。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT to the repository root}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb-repro}"
mkdir -p "${REPRO_ROOT}"
printf 'repro_root_ready=yes\n'
```

预期输出：

```text
repro_root_ready=yes
```

通过标准：退出码为 0，且 `${REPRO_ROOT}` 不指向生产知识目录。

失败处理：修正变量后重试，不使用隐式当前目录或真实用户 settings。
