# 从固定来源重建 portable 知识

状态：`UNPUBLISHED_W3_DRAFT`、`PENDING_W4_CLI_REGISTRATION`。不可发布。

## 测试目标

目的：发布后只使用 source lock 中的公开固定来源重建逻辑知识，不依赖发布者机器、
用户凭据、latest 分支或隐式工作目录。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| source coverage | inventory 全覆盖，缺失=0 |
| raw/normalized/index | 7,818 / 7,978 / 7,978 |
| record deletion / semantic diff | 0 / 0 |
| unmapped/path/leakage | 0 / 0 / 0 |
| reference manifest parity | exact |
| 临时 clone | 清理后残留=0 |

通过标准：固定来源、逻辑内容和 portable proof 全部匹配 Release reference。

失败处理：上游不可达、hash 漂移或 unmapped 大于 0 时停止；不扩大 allowlist、不使用
latest、不读取用户凭据。

## 重要边界

路径可包含空格。local root map 只能位于 `${REPRO_ROOT}`，不进入 Git、Release、
知识 metadata 或日志。生成来源必须禁网，外部 Git 来源必须匿名读取固定 commit/tree。

## 第 1 步：建立临时 HOME 与 source root

目的：证明重建不依赖真实用户 settings。

工作目录：任意目录。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro rebuild}"
export REPRO_HOME="${REPRO_ROOT}/empty home"
export SOURCE_ROOT="${REPRO_ROOT}/pinned sources"
mkdir -p "${REPRO_HOME}" "${SOURCE_ROOT}"
HOME="${REPRO_HOME}" env | rg '^HOME='
```

预期输出：

```text
HOME=<REPRO_ROOT>/empty home
```

通过标准：HOME 指向空的临时目录，源码根位于 `${REPRO_ROOT}`。

失败处理：检查带空格路径的引号；不得回退到真实 HOME。

## 第 2 步：校验公开契约处于草案态

目的：阻止未冻结 source lock 被用于认证重建。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
jq -e '.identityStatus == "planned"' \
  reproducibility/manifests/environment-lock.json >/dev/null
rc=$?
echo "planned_identity_exit=${rc}"
```

预期输出：

```text
planned_identity_exit=0
```

通过标准：W3 必须确认环境身份仍为 planned，并停止认证构建。

失败处理：若不是 planned，只能在 W4/W5 冻结流程中核对真实 manifest，不能手填值。

环境证明使用三个不同的哈希：`environmentManifestHash` 覆盖完整规范化
environment lock；`certifiedRunInputHash` 仅排除既有的
`runCandidateCommit`；`observedEnvironmentProjectionHash` 仅将
`attestationAuthorityHash` 置空后计算，用于避免 authority manifest 与其自身
哈希形成循环。authority manifest 固定 projection hash，environment lock 则固定
authority 的仓库相对路径和完整文件哈希；两者不能由 CLI 覆盖。

冻结采用两个提交：`runCandidateCommit` 指向包含全部运行关键源码和公开输入的
候选提交 A；冻结后的 environment lock 和 authority manifest 写入后继证据提交 B。
运行 worktree 必须干净且 HEAD 精确等于 A；只读证据 worktree 必须干净且 HEAD 等于
B。preflight 要求 A 是 B 的祖先，并且 A 到 B 只修改且必须修改上述两个派生证据文件。
探测成功后仍将 observed `runCandidateCommit` 记为 A，而不是把 B 写回 lock，从而避免
Git commit 对自身哈希的循环依赖；同时将 B 作为
`attestationEvidenceCommit` 写入 preflight 结果，供后续 reference evidence 审计，
但 B 不进入 `certifiedRunInputHash`。

```bash
git worktree add --detach "${RUNNER_ROOT}" "${RUN_CANDIDATE_COMMIT}"
git worktree add --detach "${EVIDENCE_ROOT}" "${ATTESTATION_EVIDENCE_COMMIT}"
export CKB_REPRO_REPOSITORY_ROOT="${RUNNER_ROOT}"
export CKB_REPRO_COMPOSITION_MANIFEST="${REPRO_ROOT}/reproducibility/manifests/runtime-composition.json"
```

`CKB_REPRO_COMPOSITION_MANIFEST`必须指向独立的私有composition root，不得位于
execution或evidence Git worktree。environment lock只保存固定相对布局和文件哈希，
不会保存本机绝对路径；探针按该显式环境变量读取并校验canonical path、固定文件后缀
和完整哈希。这样两个Git worktree保持clean，私有authority也不会进入Git。

## 第 3 步：生成一次性 local-root map 位置

目的：为 W4 的确定性 normalizer 预留显式输入，不泄漏机器路径。

工作目录：`${REPRO_ROOT}`。

命令：

```bash
export LOCAL_ROOT_MAP="${REPRO_ROOT}/local-root-map.json"
test ! -e "${LOCAL_ROOT_MAP}"
rc=$?
echo "map_absent_exit=${rc}"
```

预期输出：

```text
map_absent_exit=0
```

通过标准：草案不生成含真实根目录的 map。

失败处理：若文件已存在，确认它属于本次临时运行后删除；不得提交或打印其正文。

## 待 W4 激活的构建步骤

真实 `ckb-repro-build` 尚未在 `src/main.cj` 注册，状态为
`PENDING_W4_CLI_REGISTRATION`。激活后固定顺序为：

1. 验证 tag、`source-lock.json`、source inventory、knowledge selection、
   source materials 和 portable path policy。
2. 匿名获取每个 external source 的固定 commit/tree 并逐文件验 hash。
3. 在禁网环境执行 generated source builder。
4. 通过 `--local-root-map` 运行 official pipeline。
5. 核对 7,818/7,978/7,978、record deletion=0、semantic diff=0。
6. unmapped 或机器路径 finding 非零时输出 `hash_mismatch_stop` 并停止。
7. 执行 leakage gate；非零时输出 `leakage_finding_stop`。
8. 与 portable reference manifest 对账并绑定参考 Qdrant snapshot。
9. 重放 REST/MCP stdio/MCP HTTP parity。
10. 清理 `${SOURCE_ROOT}` 并确认残留 clone=0。

不得把以上名称当作当前可执行 shell 命令。
